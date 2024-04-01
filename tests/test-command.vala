namespace Tests
{
    private struct Case
    {
        public string   line;
        public string[] expected_args;
        public int      expected_error_code;
    }


    private inline void assert_command_error (GLib.Error error,
                                              int        expected_error_code)
    {
        var error_domain = GLib.Quark.from_string ("pomodoro-command-error-quark");

        assert_error (error, error_domain, expected_error_code);
    }


    public class CommandTest : Tests.TestSuite
    {
        static Case[] BASE_CASES =
        {
            { "foo bar", { "foo", "bar" }, -1 },
            { "foo 'bar'", { "foo", "bar" }, -1 },
            { "foo \"bar\"", { "foo", "bar" }, -1 },
            { "foo '' 'bar'", { "foo", "", "bar" }, -1 },
            { "foo \"bar\"'baz'blah'foo'\\''blah'\"boo\"", { "foo", "barbazblahfoo'blahboo" }, -1 },
            { "foo \t \tblah\tfoo\t\tbar  baz", { "foo", "blah", "foo", "bar", "baz" }, -1 },
            { "foo '    spaces more spaces lots of     spaces in this   '  \t", { "foo", "    spaces more spaces lots of     spaces in this   " }, -1 },
            { "foo \\\nbar", { "foo", "bar" }, -1 },
            { "foo '' ''", { "foo", "", "" }, -1 },
            { "foo \\\" la la la", { "foo", "\"", "la", "la", "la" }, -1 },
            { "foo \\ foo woo woo\\ ", { "foo", " foo", "woo", "woo " }, -1 },
            { "foo \"yada yada \\$\\\"\"", { "foo", "yada yada $\"" }, -1 },
            { "foo \"c:\\\\\"", { "foo", "c:\\" }, -1 },
            { "foo # comment\n bar", { "foo", "bar" }, -1 },
            { "foo a#b", { "foo", "a#b" }, -1 },
            { "foo '/bar/summer'\\''09 tours.pdf'", { "foo", "/bar/summer'09 tours.pdf" }, -1},
            { "foo bar \"", { }, Pomodoro.CommandError.SYNTAX_ERROR },
            { "foo 'bar baz", { }, Pomodoro.CommandError.SYNTAX_ERROR },
            { "foo '\"bar\" baz", { }, Pomodoro.CommandError.SYNTAX_ERROR },
            { "foo bar \\", { }, Pomodoro.CommandError.SYNTAX_ERROR },
            { "", { }, Pomodoro.CommandError.EMPTY_LINE },
            { "  ", { }, Pomodoro.CommandError.EMPTY_LINE },
            { "# comment", { }, Pomodoro.CommandError.EMPTY_LINE },
        };

        static Case[] CASES_WITH_VARIABLES =
        {
            { "echo A${}B", { "echo", "AB" }, -1 },
            { "echo A${:format}B", { "echo", "AB" }, -1 },
            { "echo $", { "echo", "$" }, -1 },
            { "echo $@", { "echo", "$@" }, -1 },
            { "echo $$@", { "echo", "$$@" }, -1 },
            { "echo $timestamp", { "echo", "1200000" }, -1 },
            { "echo @$timestamp", { "echo", "@1200000" }, -1 },
            { "echo $timestamp@", { "echo", "1200000@" }, -1 },
            { "echo 時間$timestamp", { "echo", "時間1200000" }, -1 },
            { "echo #comment: $timestamp", { "echo" }, -1 },
            { "echo ${timestamp}", { "echo", "1200000" }, -1 },
            { "echo ${timestamp:iso8601}", { "echo", "1970-01-01T00:00:01.200000Z" }, -1 },
            { "echo ${timestamp:seconds}", { "echo", "1.2" }, -1 },
            { "echo ${timestamp:microseconds}", { "echo", "1200000" }, -1 },
            { "echo ${timestamp", { "echo", "${timestamp" }, -1 },
            { "echo @${timestamp}", { "echo", "@1200000" }, -1 },
            { "echo ${timestamp}@", { "echo", "1200000@" }, -1 },
            // { "echo ${ timestamp }", { "echo", "1200000" }, -1 },  // TODO
            { "echo $state", { "echo", "short-break" }, -1 },
            { "echo ${state}", { "echo", "short-break" }, -1 },
            { "echo ${state:base}", { "echo", "break" }, -1 },
            { "echo '$state:$timestamp'", { "echo", "short-break:1200000" }, -1 },
            { "echo ${isRunning}", { "echo", "false" }, -1 },
        };

        private GLib.MainLoop? main_loop = null;
        private uint           timeout_id = 0;

        public CommandTest ()
        {
            this.add_test ("validate__empty_line", this.test_validate__empty_line);
            this.add_test ("validate__syntax_error", this.test_validate__syntax_error);
            this.add_test ("validate__not_found", this.test_validate__not_found);
            this.add_test ("validate__unknown_variable", this.test_validate__unknown_variable);
            this.add_test ("validate__unknown_variable_format", this.test_validate__unknown_variable_format);

            this.add_test ("prepare", this.test_prepare);
            this.add_test ("prepare__variables", this.test_prepare__variables);
            this.add_test ("prepare__use_subshell", this.test_prepare__use_subshell);

            this.add_test ("execute", this.test_execute);
            this.add_test ("execute__use_subshell", this.test_execute__use_subshell);
            this.add_test ("execute__working_directory", this.test_execute__working_directory);
            this.add_test ("execute__empty_line", this.test_execute__empty_line);
        }

        public override void setup ()
        {
            this.main_loop = new GLib.MainLoop ();
        }

        public override void teardown ()
        {
            this.main_loop = null;
        }

        private bool run_main_loop (uint timeout = 1000)
        {
            var success = true;

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.timeout_id = GLib.Timeout.add (timeout, () => {
                this.timeout_id = 0;
                this.main_loop.quit ();

                success = false;

                return GLib.Source.REMOVE;
            });

            this.main_loop.run ();

            return success;
        }

        private void quit_main_loop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.main_loop.quit ();
        }

        private Pomodoro.CommandExecution? execute_sync (Pomodoro.Command command,
                                                         Pomodoro.Context context)
                                                         throws Pomodoro.CommandError
        {
            Pomodoro.CommandError?     error = null;
            Pomodoro.CommandExecution? execution = null;

            command.execute_async.begin (
                context,
                (obj, res) => {
                    this.quit_main_loop ();

                    try {
                        execution = command.execute_async.end (res);
                    }
                    catch (Pomodoro.CommandError _error) {
                        GLib.warning ("Execute error: %s", error.message);
                        error = _error;
                    }
                });

            assert_true (this.run_main_loop ());

            if (error != null) {
                throw error;
            }

            return (owned) execution;
        }


        public void test_validate__empty_line ()
        {
            var command = new Pomodoro.Command ("");

            Pomodoro.CommandError? error = null;

            try {
                command.validate ();
            }
            catch (Pomodoro.CommandError _error) {
                error = _error;
            }

            assert_command_error (error, Pomodoro.CommandError.EMPTY_LINE);
        }

        public void test_validate__syntax_error ()
        {
            var command = new Pomodoro.Command ("echo \"unclosed");

            Pomodoro.CommandError? error = null;

            try {
                command.validate ();
            }
            catch (Pomodoro.CommandError _error) {
                error = _error;
            }

            assert_command_error (error, Pomodoro.CommandError.SYNTAX_ERROR);
        }

        public void test_validate__not_found ()
        {
            var command = new Pomodoro.Command ("@non-existing@");

            Pomodoro.CommandError? error = null;

            try {
                command.validate ();
            }
            catch (Pomodoro.CommandError _error) {
                error = _error;
            }

            assert_command_error (error, Pomodoro.CommandError.NOT_FOUND);
        }

        public void test_validate__unknown_variable ()
        {
            var command = new Pomodoro.Command ("echo ${invalid}");

            Pomodoro.CommandError? error = null;

            try {
                command.validate ();
            }
            catch (Pomodoro.CommandError _error) {
                error = _error;
            }

            assert_command_error (error, Pomodoro.CommandError.UNKNOWN_VARIABLE);
        }

        public void test_validate__unknown_variable_format ()
        {
            var command = new Pomodoro.Command ("echo ${timestamp:invalid}");

            Pomodoro.CommandError? error = null;

            try {
                command.validate ();
            }
            catch (Pomodoro.CommandError _error) {
                error = _error;
            }

            assert_command_error (error, Pomodoro.CommandError.UNKNOWN_VARIABLE_FORMAT);
        }

        private void test_prepare_case (Pomodoro.Context context,
                                        string           line,
                                        string[]         expected_args,
                                        int              expected_error_code)
        {
            var command = new Pomodoro.Command (line);
            Pomodoro.CommandError? error = null;

            var execution = command.prepare (context);
            assert_cmpstrv (execution.args, expected_args);

            if (expected_error_code < 0) {
                assert_no_error (execution.error);
            }
            else {
                assert_command_error (execution.error, expected_error_code);
            }
        }

        public void test_prepare ()
        {
            var context = new Pomodoro.Context ();

            foreach (var _case in BASE_CASES)
            {
                this.test_prepare_case (context,
                                        _case.line,
                                        _case.expected_args,
                                        _case.expected_error_code);
            }
        }

        public void test_prepare__variables ()
        {
            var context = new Pomodoro.Context ();
            context.timestamp = 1200000;
            context.timer_state = Pomodoro.TimerState () {
                started_time = 1000000,
                paused_time = 1200000,
            };
            context.time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);

            foreach (var _case in CASES_WITH_VARIABLES)
            {
                this.test_prepare_case (context,
                                        _case.line,
                                        _case.expected_args,
                                        _case.expected_error_code);
            }
        }

        public void test_prepare__use_subshell ()
        {
            var context = new Pomodoro.Context ();
            context.timestamp = 1200000;
            context.time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);

            var command = new Pomodoro.Command ("echo ${state} && echo ${timestamp}");
            command.use_subshell = true;

            var execution = command.prepare (context);
            assert_cmpstrv (execution.args, { "sh", "-c", "echo short-break && echo 1200000" });
            assert_no_error (execution.error);
        }

        public void test_execute ()
        {
            var command = new Pomodoro.Command ("echo hello");
            var context = new Pomodoro.Context ();

            try {
                var execution = this.execute_sync (command, context);
                assert_nonnull (execution);
                assert_cmpint (execution.exit_code, GLib.CompareOperator.EQ, 0);
                assert_cmpstr (execution.output, GLib.CompareOperator.EQ, "hello\n");
                assert_no_error (execution.error);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_execute__use_subshell ()
        {
            var command = new Pomodoro.Command ("cat <<< \"hello\"");
            command.use_subshell = true;

            var context = new Pomodoro.Context ();

            try {
                var execution = this.execute_sync (command, context);
                assert_nonnull (execution);
                assert_cmpint (execution.exit_code, GLib.CompareOperator.EQ, 0);
                assert_cmpstr (execution.output, GLib.CompareOperator.EQ, "hello\n");
                assert_no_error (execution.error);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_execute__working_directory ()
        {
            var command = new Pomodoro.Command ("pwd");
            command.working_directory = "/tmp";

            var context = new Pomodoro.Context ();

            try {
                var execution = this.execute_sync (command, context);
                assert_nonnull (execution);
                assert_cmpint (execution.exit_code, GLib.CompareOperator.EQ, 0);
                assert_cmpstr (execution.output, GLib.CompareOperator.EQ, "/tmp\n");
                assert_no_error (execution.error);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_execute__empty_line ()
        {
            var command = new Pomodoro.Command ("");
            var context = new Pomodoro.Context ();

            try {
                var execution = this.execute_sync (command, context);
                assert_cmpint (execution.exit_code, GLib.CompareOperator.EQ, -1);
                assert_cmpstr (execution.output, GLib.CompareOperator.EQ, "");
                assert_command_error (execution.error, Pomodoro.CommandError.EMPTY_LINE);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CommandTest ()
    );
}
