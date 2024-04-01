/*
 * Copyright (c) 2016,2024 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

using GLib;


namespace Pomodoro
{
    /**
     * Default timeout in seconds. The intent is to prevent commands from blocking the task queue.
     */
    private const int COMMAND_TIMEOUT = 10;


    public enum ActionTrigger
    {
        EVENT,
        CONDITION
    }


    public abstract class Action : GLib.Object
    {
        public string? uuid
        {
            get {
                return this._uuid;
            }
            construct {
                this._uuid = value;
            }
        }

        public GLib.Settings? settings
        {
            get {
                return this._settings;
            }
        }

        [CCode (notify = false)]
        public bool enabled
        {
            get {
                return this._enabled;
            }
            set {
                if (this._enabled != value)
                {
                    this._enabled = value;
                    this.notify_property ("enabled");
                }
            }
        }

        public string display_name { get; set; default = ""; }

        private string?        _uuid = null;
        private GLib.Settings? _settings = null;
        private bool           _enabled = true;

        internal void set_uuid_internal (string uuid)
        {
            this._uuid = uuid;
        }

        public virtual void load (GLib.Settings settings)
        {
            this._settings = settings;

            this.enabled = settings.get_boolean ("enabled");
            this.display_name = settings.get_string ("display-name");
        }

        public virtual void save (GLib.Settings settings)
        {
            this._settings = settings;

            settings.set_boolean ("enabled", this.enabled);
            settings.set_string ("display-name", this.display_name);
        }

        public virtual void bind ()
        {
            assert_not_reached ();
        }

        public virtual void unbind ()
        {
            assert_not_reached ();
        }
    }


    public class EventAction : Pomodoro.Action
    {
        public string[] event_names { get; set; }
        public Pomodoro.Expression? condition { get; set; }
        public Pomodoro.Command command { get; set; }
        public bool wait_for_completion { get; set; default = true; }

        private Pomodoro.EventBus bus;
        private uint[]            watch_ids;
        private uint              last_context_checksum = 0;

        construct
        {
            this.bus = new Pomodoro.EventBus ();
            this.watch_ids = new uint[0];
        }

        public EventAction (string? uuid = null)
        {
            GLib.Object (
                uuid: uuid
            );
        }

        public override void load (GLib.Settings settings)
        {
            base.load (settings);

            var condition_string = settings.get_string ("condition");
            Pomodoro.Expression? condition = null;

            if (condition_string != "")
            {
                var parser = new Pomodoro.ExpressionParser ();

                try {
                    condition = parser.parse (condition_string);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    GLib.warning ("Failed to parse action condition: `%s`", condition_string);
                }
            }

            this.event_names = settings.get_strv ("events");
            this.condition = condition;
            this.wait_for_completion = settings.get_boolean ("wait-for-completion");

            this.command = new Pomodoro.Command (settings.get_string ("command"));
            this.command.working_directory = settings.get_string ("working-directory");
            this.command.use_subshell = settings.get_boolean ("use-subshell");
            this.command.pass_input = settings.get_boolean ("pass-input");
        }

        public override void save (GLib.Settings settings)
        {
            var command = this.command;
            var condition = this.condition;

            base.save (settings);

            settings.set_enum ("trigger", Pomodoro.ActionTrigger.EVENT);
            settings.set_strv ("events", this.event_names);
            settings.set_boolean ("wait-for-completion", this.wait_for_completion);

            if (condition != null) {
                settings.set_string ("condition", condition.to_string ());
            }
            else {
                settings.reset ("condition");
            }

            if (command != null) {
                settings.set_string ("command", ensure_string (command.line));
                settings.set_string ("working-directory", ensure_string (command.working_directory));
                settings.set_boolean ("use-subshell", command.use_subshell);
                settings.set_boolean ("pass-input", command.pass_input);
            }
            else {
                settings.reset ("command");
                settings.reset ("working-directory");
                settings.reset ("use-subshell");
                settings.reset ("pass-input");
            }
        }

        private void on_event (Pomodoro.Event event)
        {
            var command = this.command;
            var context_checksum = event.context.calculate_checksum ();
            Pomodoro.CommandExecution? execution = null;

            if (context_checksum == this.last_context_checksum) {
                // The action may be triggered by several events. Prevent executing the command if the context
                // hasn't changed.
                return;
            }

            this.last_context_checksum = context_checksum;

            if (command != null)
            {
                if (this.wait_for_completion)
                {
                    execution = command.prepare (event.context);

                    if (execution != null && !execution.completed)
                    {
                        execution.timeout = COMMAND_TIMEOUT;

                        var queue = new Pomodoro.JobQueue ();
                        queue.push (execution);
                    }
                }
                else {
                    execution = command.execute (event.context);
                }
            }

            this.triggered (event.context, execution);
        }

        public override void bind ()
        {
            if (this.enabled)
            {
                var condition = this.condition;

                foreach (var event_name in this.event_names) {
                    var watch_id = this.bus.add_event_watch (event_name, condition, this.on_event);

                    this.watch_ids += watch_id;
                }

                assert (this.watch_ids.length == this.event_names.length);
            }
        }

        public override void unbind ()
        {
            foreach (var watch_id in this.watch_ids) {
                this.bus.remove_event_watch (watch_id);
            }

            this.watch_ids = {};
        }

        public signal void triggered (Pomodoro.Context           context,
                                      Pomodoro.CommandExecution? execution);
    }


    public class ConditionAction : Pomodoro.Action
    {
        public Pomodoro.Expression condition { get; set; }
        public Pomodoro.Command enter_command { get; set; }
        public Pomodoro.Command exit_command { get; set; }

        private Pomodoro.EventBus bus;
        private uint              watch_id = 0;

        construct
        {
            this.bus = new Pomodoro.EventBus ();
        }

        public ConditionAction (string? uuid = null)
        {
            GLib.Object (
                uuid: uuid
            );
        }

        public override void load (GLib.Settings settings)
        {
            base.load (settings);

            var condition_string = settings.get_string ("condition");
            Pomodoro.Expression? condition = null;

            if (condition_string != "")
            {
                var parser = new Pomodoro.ExpressionParser ();

                try {
                    condition = parser.parse (condition_string);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    GLib.warning ("Failed to parse action condition: `%s`", condition_string);
                }
            }

            this.condition = condition;

            this.enter_command = new Pomodoro.Command (settings.get_string ("command"));
            this.enter_command.working_directory = settings.get_string ("working-directory");
            this.enter_command.use_subshell = settings.get_boolean ("use-subshell");
            this.enter_command.pass_input = settings.get_boolean ("pass-input");

            this.exit_command = new Pomodoro.Command (settings.get_string ("exit-command"));
            this.exit_command.working_directory = settings.get_string ("working-directory");
            this.exit_command.use_subshell = settings.get_boolean ("use-subshell");
            this.exit_command.pass_input = settings.get_boolean ("pass-input");
        }

        public override void save (GLib.Settings settings)
        {
            var condition     = this.condition;
            var enter_command = this.enter_command;
            var exit_command  = this.exit_command;
            var any_command   = enter_command != null ? enter_command : exit_command;

            base.save (settings);

            settings.set_enum ("trigger", Pomodoro.ActionTrigger.CONDITION);

            if (condition != null) {
                settings.set_string ("condition", condition.to_string ());
            }
            else {
                settings.reset ("condition");
            }

            if (enter_command != null) {
                settings.set_string ("command", ensure_string (enter_command.line));
            }
            else {
                settings.reset ("command");
            }

            if (exit_command != null) {
                settings.set_string ("exit-command", ensure_string (exit_command.line));
            }
            else {
                settings.reset ("exit-command");
            }

            if (any_command != null) {
                settings.set_string ("working-directory", ensure_string (any_command.working_directory));
                settings.set_boolean ("use-subshell", any_command.use_subshell);
                settings.set_boolean ("pass-input", any_command.pass_input);
            }
            else {
                settings.reset ("working-directory");
                settings.reset ("use-subshell");
                settings.reset ("pass-input");
            }
        }

        private void on_enter_condition (Pomodoro.Context context)
        {
            var command = this.enter_command;
            Pomodoro.CommandExecution? execution = null;

            if (command != null)
            {
                execution = command.prepare (context);

                if (execution != null && !execution.completed)
                {
                    execution.timeout = COMMAND_TIMEOUT;

                    var queue = new Pomodoro.JobQueue ();
                    queue.push (execution);
                }
            }

            this.entered_condition (context, execution);
        }

        private void on_exit_condition (Pomodoro.Context context)
        {
            var command = this.exit_command;
            Pomodoro.CommandExecution? execution = null;

            if (command != null)
            {
                execution = command.prepare (context);

                if (execution != null && !execution.completed)
                {
                    execution.timeout = COMMAND_TIMEOUT;

                    var queue = new Pomodoro.JobQueue ();
                    queue.push (execution);
                }
            }

            this.exited_condition (context, execution);
        }

        public override void bind ()
        {
            if (this.enabled && this.condition != null && this.watch_id == 0)
            {
                this.watch_id = this.bus.add_condition_watch (this.condition,
                                                              this.on_enter_condition,
                                                              this.on_exit_condition);
            }
        }

        public override void unbind ()
        {
            if (this.watch_id != 0)
            {
                this.bus.remove_condition_watch (this.watch_id);

                this.watch_id = 0;
            }
        }

        public signal void entered_condition (Pomodoro.Context           context,
                                              Pomodoro.CommandExecution? execution);

        public signal void exited_condition (Pomodoro.Context           context,
                                             Pomodoro.CommandExecution? execution);
    }
}
