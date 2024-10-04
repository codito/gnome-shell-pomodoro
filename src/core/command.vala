using GLib;


namespace Pomodoro
{
    private struct CommandVariable
    {
        public string name_raw;
        public string name;
        public string format_raw;
        public string format;
        public int    span_start;
        public int    span_end;
        public int    arg_index;

        public CommandVariable ()
        {
            this.span_start = -1;
            this.span_end = -1;
        }
    }


    private void find_variables (string                      text,
                                 GLib.Func<CommandVariable?> callback)
    {
        unichar chr;
        int     chr_span_start = 0;
        int     chr_span_end = 0;

        var variable = CommandVariable ();
        var within_brackets = false;

        while (text.get_next_char (ref chr_span_end, out chr))
        {
            if (variable.span_start < 0)
            {
                if (chr == '$') {
                    variable.span_start = chr_span_start;
                }
            }
            else
            {
                if (!within_brackets)
                {
                    if (chr == '{' && chr_span_start == variable.span_start + 1) {
                        within_brackets = true;
                    }
                    else if (!chr.isalnum ())
                    {
                        variable.span_end = chr_span_start;
                        variable.name_raw = text.slice ((long) variable.span_start + 1,
                                                        (long) variable.span_end);
                        variable.name = from_camel_case (variable.name_raw);
                        variable.format_raw = "";
                        variable.format = "";

                        if (variable.name != "") {
                            callback (variable);
                        }

                        variable = CommandVariable ();
                    }
                }
                else if (chr == '}')
                {
                    variable.span_end = chr_span_end;

                    var bracket_text = text.slice ((long) variable.span_start + 2,
                                                   (long) variable.span_end - 1);
                    var bracket_tokens = bracket_text.split (":", 2);

                    if (bracket_tokens.length == 2) {
                        variable.name_raw = bracket_tokens[0].strip ();
                        variable.name = from_camel_case (variable.name_raw);
                        variable.format_raw = bracket_tokens[1].strip ();
                        variable.format = from_camel_case (variable.format_raw);
                    }
                    else {
                        variable.name_raw = bracket_text.strip ();
                        variable.name = from_camel_case (variable.name_raw);
                        variable.format_raw = "";
                        variable.format = "";
                    }

                    callback (variable);

                    within_brackets = false;
                    variable = CommandVariable ();
                }
            }

            chr_span_start = chr_span_end;
        }

        if (variable.span_start >= 0 && !within_brackets)
        {
            variable.span_end = chr_span_end;
            variable.name = text.slice ((long) variable.span_start + 1, (long) variable.span_end);
            variable.format = "";

            if (variable.name != "") {
                callback (variable);
            }
        }
    }


    private string? find_program_in_host_path (string program)
    {
        if (program == null) {
            return null;
        }

        if (Pomodoro.is_flatpak ())
        {
            string standard_output;
            int wait_status;

            try {
                GLib.Process.spawn_sync (null,
                                         { "flatpak-spawn", "--host", "which", program },
                                         null,
                                         GLib.SpawnFlags.SEARCH_PATH | GLib.SpawnFlags.STDERR_TO_DEV_NULL,
                                         setup_child,
                                         out standard_output,
                                         null,
                                         out wait_status);

                if (wait_status == 0 && standard_output != null && standard_output.length > 0) {
                    return standard_output;
                }
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Error finding program: %s", error.message);
            }

            return null;
        }
        else {
            return GLib.Environment.find_program_in_path (program);
        }
    }


    private void setup_child ()
    {
        // Create new session to detach from tty, but set a process.
        Posix.setsid ();

        // Group so all children can be ḱilled if need be.
        Posix.setpgid (0, 0);
    }


    public errordomain CommandError
    {
        EMPTY_LINE,
        SYNTAX_ERROR,
        UNKNOWN_VARIABLE,
        UNKNOWN_VARIABLE_FORMAT,
        NOT_FOUND,
        FAILED
    }


    /**
     * Object representing a single execution of a command - its arguments and output.
     *
     * It's an object because we may display it in the Log UI and updates are applied on its own.
     */
    public class CommandExecution : GLib.Object, Pomodoro.Job
    {
        private const GLib.SpawnFlags SPAWN_FLAGS = GLib.SpawnFlags.SEARCH_PATH |
                                                    GLib.SpawnFlags.LEAVE_DESCRIPTORS_OPEN |
                                                    GLib.SpawnFlags.DO_NOT_REAP_CHILD;

        public string[]    args { get; construct; }
        public string?     working_directory { get; construct; }
        public string      input { get; set; default = ""; }
        public int         timeout { get; set; default = -1; }
        public int         exit_code { get; private set; default = -1; }
        public string      output { get; private set; default = ""; }
        public int64       execution_time { get; private set; default = 0; }

        [CCode (notify = false)]
        public bool completed {
            get {
                return this._completed;
            }
            set {
                if (this._completed != value) {
                    this._completed = value;
                    this.notify_property ("completed");
                }
            }
        }

        public GLib.Error? error {
            get {
                return this._error;
            }
            set {
                this._error = value;
            }
        }

        private GLib.Cancellable? cancellable = null;
        private GLib.Error?       _error = null;
        private bool              _completed = false;

        public CommandExecution (string[] args,
                                 string?  working_directory)
        {
            GLib.Object (
                args: args,
                working_directory: working_directory
            );
        }

        private static bool process_output_line (GLib.IOChannel     channel,
                                                 GLib.IOCondition   condition,
                                                 GLib.StringBuilder output)
        {
            if (condition == GLib.IOCondition.HUP) {
		        return false;
	        }

            try {
                string line;
                channel.read_line (out line, null, null);

                output.append (line);
            }
            catch (GLib.IOChannelError error) {
                GLib.debug ("IOChannelError: %s", error.message);
                return false;
            }
            catch (GLib.ConvertError error) {
                GLib.debug ("ConvertError: %s", error.message);
                return false;
            }

	        return true;
        }

        /**
         * TODO: Currently there may be several executions ongoing for a command - it should always
         *       execute once at a time
         */
        public async bool run ()
                               throws GLib.Error
                               requires (this.cancellable == null)
        {
            if (this._error != null) {
                throw this._error.copy ();
            }

            GLib.SourceFunc? callback = null;
            GLib.Pid         child_pid;
            int              standard_input;
            int              standard_output;
            int              standard_error;
            uint             timeout_id = 0;
            string[]         args;
            var              timeout = this.timeout;
            var              working_directory = this.working_directory;
            var              output_builder = new GLib.StringBuilder ();

            this.cancellable = new GLib.Cancellable ();

            try {
                if (Pomodoro.is_flatpak ())
                {
                    string[] flatpak_spawn_args = { "flatpak-spawn", "--host" };

                    if (working_directory != null) {
                        flatpak_spawn_args += @"--directory=$(working_directory)";
                        working_directory = null;
                    }

                    foreach (var arg in this.args) {
                        flatpak_spawn_args += arg;
                    }

                    args = flatpak_spawn_args;
                }
                else {
                    args = this.args;
                }

                var start_time = GLib.get_monotonic_time ();

                GLib.Process.spawn_async_with_pipes (working_directory,
                                                     args,
                                                     null,
                                                     SPAWN_FLAGS,
                                                     setup_child,
                                                     out child_pid,
                                                     out standard_input,
                                                     out standard_output,
                                                     out standard_error);

                if (this.input != "")
                {
                    var input_channel = new GLib.IOChannel.unix_new (standard_input);

                    try {
                        input_channel.write_chars (this.input.to_utf8 (), null);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Failed to pass JSON data: %s", error.message);
                    }

                    input_channel.shutdown (true);
                }

                var output_channel = new GLib.IOChannel.unix_new (standard_output);
                output_channel.add_watch (
                    GLib.IOCondition.IN | GLib.IOCondition.HUP,
                    (channel, condition) => {
                        return process_output_line (channel, condition, output_builder);
	                });

                var error_channel = new GLib.IOChannel.unix_new (standard_error);
                error_channel.add_watch (
                    GLib.IOCondition.IN | GLib.IOCondition.HUP,
                    (channel, condition) => {
                        return process_output_line (channel, condition, output_builder);
                    });

	            GLib.ChildWatch.add (
	                child_pid,
                    (pid, status) => {
                        // Check the exit status of the child process
                        try {
                            GLib.Process.check_wait_status (status);

                            this.exit_code = 0;
                        }
                        catch (GLib.Error error)
                        {
                            this.exit_code = error.code;

                            if (this.error == null)
                            {
                                var command_line = string.joinv (" ", this.args);
                                GLib.warning ("Spawned command '%s' exited abnormally: %s", command_line, error.message);

                                this.error = error.copy ();
                            }
                        }
                        finally {
                            this.execution_time = GLib.get_monotonic_time () - start_time;
                            this.output = output_builder.str;
                        }

                        if (callback != null) {
                            callback ();
                        }
	                });

                callback = run.callback;

                if (timeout > 0) {
                    timeout_id = GLib.Timeout.add_seconds (
                        timeout,
                        () => {
                            timeout_id = 0;

                            this.error = new Pomodoro.CommandError.FAILED (_("Reached timeout"));

                            this.cancellable.cancel ();

                            return GLib.Source.REMOVE;
                        });
                    GLib.Source.set_name_by_id (timeout_id, "Pomodoro.CommandExecution.run");
                }

                this.cancellable.cancelled.connect (
                    () => {
                        if (this.exit_code < 0) {
                            var command_line = string.joinv (" ", this.args);
                            GLib.debug ("Cancel command `%s` with pid=%d", command_line, child_pid);

                            Posix.kill (child_pid, Posix.Signal.TERM);
                        }
                    });

                yield;

                GLib.Process.close_pid (child_pid);

                // TODO: are file descriptors closed properly?
            }
            catch (GLib.SpawnError error) {
                var command_line = string.joinv (" ", this.args);
                GLib.warning ("Error while spawning command `%s`: %s", command_line, error.message);

                this.error = new Pomodoro.CommandError.FAILED (_("Failed to execute command"));

                throw this.error;
            }
            finally {
                if (timeout_id != 0) {
                    GLib.Source.remove (timeout_id);
                    timeout_id = 0;
                }

                this.completed = true;
            }

            return this.error == null && this.exit_code == 0;
        }

        public string get_line ()
        {
            var line = new GLib.StringBuilder ();
            var index = 0;

            foreach (var arg in this.args)
            {
                if (index > 0) {
                    line.append_c (' ');
                }

                line.append (arg);  // TODO: escape / quote string
                index++;
            }

            return line.str;
        }
    }


    public class Command : GLib.Object
    {
        public string line {
            get {
                return this._line;
            }
            set {
                if (this._line != value) {
                    this._line = value;
                    this.prepared = false;
                }
            }
        }
        public bool use_subshell {
            get {
                return this._use_subshell;
            }
            set {
                if (this._use_subshell != value) {
                    this._use_subshell = value;
                    this.prepared = false;
                }
            }
        }
        public string working_directory { get; set; }
        public bool   pass_input { get; set; default = false; }

        private string            _line;
        private bool              _use_subshell = false;
        private bool              prepared = false;
        private string[]          args;
        private CommandVariable[] variables;

        public Command (string line)
        {
            GLib.Object (
                line: line
            );
        }

        private void prepare_args () throws Pomodoro.CommandError
        {
            if (this._use_subshell)
            {
                var line = this._line.strip ();

                if (line.length == 0) {
                    throw new Pomodoro.CommandError.EMPTY_LINE (_("Command is empty"));
                }

                // We don't have a way to validate the shell command, so use it as is.
                this.args = { "sh", "-c", line };
            }
            else {
                try {
                    GLib.Shell.parse_argv (this._line, out this.args);
                }
                catch (GLib.ShellError error)
                {
                    this.args = { line };

                    if (error is GLib.ShellError.EMPTY_STRING) {
                        throw new Pomodoro.CommandError.EMPTY_LINE (_("Command is empty"));
                    }

                    if (error is GLib.ShellError.BAD_QUOTING) {
                        throw new Pomodoro.CommandError.SYNTAX_ERROR (_("Unclosed quotation mark"));
                    }

                    GLib.warning ("Unexpected error while parsing command '%s': %s",
                                  this._line, error.message);
                    throw new Pomodoro.CommandError.SYNTAX_ERROR (_("Invalid command"));
                }
            }
        }

        private void prepare_variables () throws Pomodoro.CommandError
                                        requires (this.args != null)
        {
            var variables = new CommandVariable[0];

            for (var index = 0; index < this.args.length; index++)
            {
                Pomodoro.CommandError? error = null;

                find_variables (
                    this.args[index],
                    (variable) => {
                        if (error != null) {
                            return;
                        }

                        if (variable.name != "")
                        {
                            if (Pomodoro.find_variable (variable.name) == null) {
                                error = new Pomodoro.CommandError.UNKNOWN_VARIABLE (
                                        _("Unknown variable \"%s\""), variable.name_raw);
                                return;
                            }

                            if (!Pomodoro.find_variable_format (variable.name, variable.format)) {
                                error = new Pomodoro.CommandError.UNKNOWN_VARIABLE_FORMAT (
                                        _("Unknown format \"%s\""), variable.format_raw);
                                return;
                            }
                        }

                        variable.arg_index = index;
                        variables += variable;
                    });

                if (error != null) {
                    throw error;
                }
            }

            this.variables = variables;
        }

        private string[] interpolate_args (Pomodoro.Context context)
                                           requires (this.args != null)
        {
            var args = this.args.copy ();

            for (var index = this.variables.length - 1; index >= 0; index--)
            {
                var variable = this.variables[index];
                var variable_value = context.evaluate_variable (variable.name);
                var variable_string = "";

                if (variable_value != null)
                {
                    try {
                        var variable_variant = variable_value.format (variable.format);

                        variable_string = variable_variant.is_of_type (GLib.VariantType.STRING)
                            ? variable_variant.get_string ()
                            : variable_variant.print (false);
                    }
                    catch (Pomodoro.ExpressionError error) {
                        // Error should be cough earlier, during prepare.
                    }
                }

                args[variable.arg_index] = args[variable.arg_index].splice (variable.span_start,
                                                                            variable.span_end,
                                                                            variable_string);
            }

            return args;
        }

        private void prepare_internal ()
                                       throws Pomodoro.CommandError
        {
            if (!this.prepared) {
                this.prepare_args ();
                this.prepare_variables ();
                this.prepared = true;
            }
            else {
                assert (this.args != null);
            }
        }

        public void validate () throws Pomodoro.CommandError
        {
            this.prepare_internal ();

            // TODO: we don't validate shell/bash syntax, make custom command-line parser
            if (this.args.length != 0 && !this._use_subshell)
            {
                var program_path = find_program_in_host_path (this.args[0]);

                if (program_path == null) {
                    throw new Pomodoro.CommandError.NOT_FOUND (_("Program \"%s\" not found"), this.args[0]);
                }
            }

            // TODO: validate working directory
        }

        public Pomodoro.CommandExecution? prepare (Pomodoro.Context context)  // TODO: make it private or remove; just execute and allow to cancel job
        {
            Pomodoro.CommandExecution? execution = null;

            try {
                this.prepare_internal ();

                execution = new Pomodoro.CommandExecution (this.interpolate_args (context),
                                                           this.working_directory);

                if (this.pass_input) {
                    execution.input = context.to_json ();
                }
            }
            catch (Pomodoro.CommandError error)
            {
                if (!(error is Pomodoro.CommandError.EMPTY_LINE))
                {
                    execution = new Pomodoro.CommandExecution (this.args,
                                                               this.working_directory);
                    execution.error = error;
                    execution.completed = true;
                }
            }

            return execution;
        }

        public Pomodoro.CommandExecution? execute (Pomodoro.Context context)
        {
            var execution = this.prepare (context);

            if (execution != null && !execution.completed)
            {
                execution.run.begin (
                    (obj, res) => {
                        try {
                            execution.run.end (res);
                        }
                        catch (GLib.Error error) {
                            execution.error = error;
                        }
                    });
            }

            return execution;
        }

        /**
         * TODO: Its unnecessary. `execution.run` should be async and ensure that the command
         *       is executed once.
         */
        public async Pomodoro.CommandExecution? execute_async (Pomodoro.Context context)
        {
            var execution = this.prepare (context);

            if (execution != null && execution.error == null)
            {
                try {
                    yield execution.run ();
                }
                catch (GLib.Error error) {
                    execution.error = error;
                }
            }

            return execution;
        }
    }
}
