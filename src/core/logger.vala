using GLib;


namespace Pomodoro
{
    public abstract class LogEntry : GLib.Object
    {
        public ulong id {
            get {
                return this._id;
            }
            construct {
                this._id = Pomodoro.LogEntry.next_id;

                Pomodoro.LogEntry.next_id++;
            }
        }
        public int64 timestamp { get; set; }
        public string label { get; set; }
        public Pomodoro.Context context { get; set; }

        private ulong        _id;
        private static ulong next_id = 1;
    }


    public sealed class EventLogEntry : Pomodoro.LogEntry
    {
        public string event_name {
            get {
                return this._event_name;
            }
            set {
                this._event_name = value;
            }
        }

        private string _event_name;

        public EventLogEntry (Pomodoro.Event event)
        {
            GLib.Object (
                timestamp: event.context.timestamp,
                label: event.spec.display_name,
                context: event.context,
                event_name: event.spec.name
            );
        }
    }


    public class ActionLogEntry : Pomodoro.LogEntry
    {
        public string action_uuid {
            get {
               return this._action_uuid;
            }
            set {
                this._action_uuid = value;
            }
        }

        public string event_name {
            get {
                return this._event_name;
            }
            set {
                this._event_name = value;
            }
        }

        public string command_line {
            get {
               return this._command_line;
            }
            set {
                this._command_line = value;
            }
        }

        public string command_output {
            get {
               return this._command_output;
            }
            set {
                this._command_output = value;
            }
        }

        public string command_error_message { get; set; }

        public int command_exit_code { get; set; }

        public int64 command_execution_time { get; set; }

        private string  _action_uuid;
        private string  _event_name;
        private string? _command_line;
        private string? _command_output;

        public ActionLogEntry (Pomodoro.Action            action,
                               string                     event_name,
                               Pomodoro.Context           context,
                               Pomodoro.CommandExecution? execution)
        {
            GLib.Object (
                timestamp: context.timestamp,
                label: action.display_name,
                event_name: event_name,
                context: context,
                action_uuid: action.uuid,
                command_line: execution != null ? execution.get_line () : "",
                command_error_message: null,
                command_exit_code: -1,
                command_execution_time: 0
            );
        }
    }


    [SingleInstance]
    public class Logger : GLib.Object
    {
        private const uint MAX_ENTRIES = 200;

        public GLib.ListModel model {
            get {
                return this._model;
            }
        }

        private GLib.ListStore _model = null;

        construct
        {
            // TODO: ensure model is sorted and group entries into sections,
            //       likely we will need custom model
            this._model = new GLib.ListStore (typeof (Pomodoro.LogEntry));
        }

        private bool transform_to_error_message (GLib.Binding   binding,
                                                 GLib.Value     source_value,
                                                 ref GLib.Value target_value)
        {
            var error = (GLib.Error?) source_value.get_boxed ();

            target_value.set_string (error != null ? error.message : null);

            return true;
        }

        private inline ulong log (Pomodoro.LogEntry entry)
        {
            this._model.append (entry);

            while (this._model.n_items > MAX_ENTRIES) {
                this._model.remove (0);
            }

            return entry.id;
        }

        public ulong log_event (Pomodoro.Event event)
        {
            return this.log (new Pomodoro.EventLogEntry (event));
        }

        private ulong log_action_event (Pomodoro.Action            action,
                                        string                     event_name,
                                        Pomodoro.Context           context,
                                        Pomodoro.CommandExecution? execution)
        {
            var entry = new Pomodoro.ActionLogEntry (action, event_name, context, execution);

            if (execution != null)
            {
                execution.bind_property ("output", entry, "command-output",
                                         GLib.BindingFlags.SYNC_CREATE);
                execution.bind_property ("exit-code", entry, "command-exit-code",
                                         GLib.BindingFlags.SYNC_CREATE);
                execution.bind_property ("execution-time", entry, "command-execution-time",
                                         GLib.BindingFlags.SYNC_CREATE);
                execution.bind_property ("error", entry, "command-error-message",
                                         GLib.BindingFlags.SYNC_CREATE,
                                         this.transform_to_error_message);

                if (!execution.completed) {
                    // HACK: We use `command-exit-code` to tell if job has completed.
                    //       This won't work if there's a validation error.
                    execution.notify["completed"].connect (
                        () => {
                            if (entry.command_exit_code < 0) {
                                entry.notify_property ("command-exit-code");
                            }
                        });
                }
            }

            return this.log (entry);
        }

        public ulong log_action_triggered (Pomodoro.EventAction       action,
                                           Pomodoro.Context           context,
                                           Pomodoro.CommandExecution? execution)
        {
            return this.log_action_event (action, "triggered", context, execution);
        }

        public ulong log_action_entered_condition (Pomodoro.ConditionAction   action,
                                                  Pomodoro.Context           context,
                                                  Pomodoro.CommandExecution? execution)
        {
            return this.log_action_event (action, "entered-condition", context, execution);
        }

        public ulong log_action_exited_condition (Pomodoro.ConditionAction   action,
                                                 Pomodoro.Context           context,
                                                 Pomodoro.CommandExecution? execution)
        {
            return this.log_action_event (action, "exited-condition", context, execution);
        }

        public override void dispose ()
        {
            this._model = null;

            base.dispose ();
        }
    }
}
