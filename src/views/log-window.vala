namespace Pomodoro
{
    private string get_event_icon_name (string event_name)
    {
        switch (event_name)
        {
            case "start":
                return "timer-start-symbolic";

            case "stop":
                return "timer-stop-symbolic";

            case "skip":
                return "timer-skip-symbolic";

            case "rewind":
                return "timer-rewind-symbolic";

            case "pause":
                return "timer-pause-symbolic";

            case "resume":
                return "timer-start-symbolic";

            case "reset":
                return "timer-reset-symbolic";

            default:
                return "event-symbolic";
        }
    }


    private string get_action_icon_name (string event_name)
    {
        switch (event_name)
        {
            case "triggered":
                return "custom-action-symbolic";

            case "entered-condition":
                return "condition-enter-symbolic";

            case "exited-condition":
                return "condition-exit-symbolic";

            default:
                return "custom-action-symbolic";
        }
    }


    /**
     * Custom model for handling sections (time headers).
     */
    private class SectionedLogModel : GLib.Object, GLib.ListModel, Gtk.SectionModel
    {
        public GLib.ListModel? model {
            get {
                return this._model;
            }
            construct {
                this._model = value;
                this._model.items_changed.connect (this.on_items_changed);
            }
        }

        private GLib.ListModel? _model = null;

        public SectionedLogModel (GLib.ListModel model)
        {
            GLib.Object (
                model: model
            );
        }

        /*
         * GLib.ListModel interface
         */

        public GLib.Object? get_item (uint position)
        {
            return this._model.get_item (position);
        }

        public GLib.Type get_item_type ()
        {
            return this._model.get_item_type ();
        }

        public uint get_n_items ()
        {
            return this._model.get_n_items ();
        }

        private void on_items_changed (uint position,
                                       uint removed,
                                       uint added)
        {
            this.items_changed (position, removed, added);

            if (added > 0) {
                this.sections_changed (position, added);
            }
        }

        /*
         * Gtk.SectionModel interface
         */

        private static inline int64 calculate_hash (int64 timestamp)
        {
            return timestamp / Pomodoro.Interval.MINUTE;
        }

        public void get_section (uint     position,
                                 out uint out_start,
                                 out uint out_end)
        {
            var reference_item = (Pomodoro.LogEntry) this._model.get_item (position);
            var reference_hash = calculate_hash (reference_item.timestamp);
            var n_items = this._model.get_n_items ();

            out_start = position;
            out_end = position + 1;

            while (out_start > 0)
            {
                var item = (Pomodoro.LogEntry) this._model.get_item (out_start - 1);

                if (calculate_hash (item.timestamp) == reference_hash) {
                    out_start--;
                }
                else {
                    break;
                }
            }

            while (out_end < n_items)
            {
                var item = (Pomodoro.LogEntry) this._model.get_item (out_end);

                if (calculate_hash (item.timestamp) == reference_hash) {
                    out_end++;
                }
                else {
                    break;
                }
            }
        }

        public override void dispose ()
        {
            if (this._model != null) {
                this._model.items_changed.disconnect (this.on_items_changed);
                this._model = null;
            }

            base.dispose ();
        }
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/log-window.ui")]
    public class LogWindow : Adw.ApplicationWindow
    {
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.ListView listview;
        [GtkChild]
        private unowned Gtk.Label header_label;
        [GtkChild]
        private unowned Gtk.Label datetime_label;
        [GtkChild]
        private unowned Gtk.Label context_label;
        [GtkChild]
        private unowned Gtk.Label command_line_header_label;
        [GtkChild]
        private unowned Gtk.Label command_line_label;
        [GtkChild]
        private unowned Gtk.Label command_error_header_label;
        [GtkChild]
        private unowned Gtk.Label command_error_message_label;
        [GtkChild]
        private unowned Gtk.Label command_output_header_label;
        [GtkChild]
        private unowned Gtk.Label command_output_label;
        [GtkChild]
        private unowned Gtk.Box command_exit_code_box;
        [GtkChild]
        private unowned Gtk.Label command_exit_code_label;
        [GtkChild]
        private unowned Gtk.Label command_execution_time_label;

        private Pomodoro.Logger    logger;
        private Pomodoro.LogEntry? selected_entry;
        private uint               update_contents_id = 0;

        construct
        {
            this.logger = new Pomodoro.Logger ();

            var model = new Gtk.SingleSelection (new SectionedLogModel (this.logger.model));
            model.autoselect = true;
            model.can_unselect = false;
            model.selection_changed.connect (this.on_selection_changed);
            model.items_changed.connect (this.on_items_changed);

            this.listview.model = model;
            this.update_contents_id = 0;

            this.update_stack_visible_child ();
            this.update_contents ();
        }

        private void update_contents ()
        {
            if (this.update_contents_id != 0) {
                this.remove_tick_callback (this.update_contents_id);
                this.update_contents_id = 0;
            }

            if (this.selected_entry != null) {
                this.selected_entry.notify.disconnect (this.on_selected_entry_notify);
                this.selected_entry = null;
            }

            var model = (Gtk.SingleSelection?) this.listview.model;
            var entry = (Pomodoro.LogEntry?) model?.selected_item;

            if (entry != null)
            {
                var datetime = new GLib.DateTime.from_unix_utc (entry.timestamp / Pomodoro.Interval.SECOND);

                this.header_label.label = entry.label;
                this.datetime_label.label = datetime != null ? datetime.to_local ().format ("%c") : "";
                this.context_label.label = entry.context != null ? entry.context.to_json () : "";

                this.command_line_header_label.visible = false;
                this.command_line_label.visible = false;
                this.command_error_header_label.visible = false;
                this.command_error_message_label.visible = false;
                this.command_output_header_label.visible = false;
                this.command_output_label.visible = false;
                this.command_exit_code_box.visible = false;

                if (entry is Pomodoro.ActionLogEntry)
                {
                    var action_entry = (Pomodoro.ActionLogEntry) entry;

                    if (action_entry.command_line != "") {
                        this.command_line_label.label = action_entry.command_line;
                        this.command_line_header_label.visible = true;
                        this.command_line_label.visible = true;
                    }

                    if (action_entry.command_error_message != null && action_entry.command_error_message != "") {
                        this.command_error_message_label.label = action_entry.command_error_message;
                        this.command_error_header_label.visible = true;
                        this.command_error_message_label.visible = true;
                    }

                    if (action_entry.command_output != null && action_entry.command_output != "") {
                        this.command_output_label.label = action_entry.command_output.strip ();
                        this.command_output_header_label.visible = true;
                        this.command_output_label.visible = true;
                    }

                    if (action_entry.command_exit_code >= 0) {
                        this.command_exit_code_box.visible = true;
                        this.command_exit_code_label.label = action_entry.command_exit_code.to_string ();
                        this.command_execution_time_label.label = "%u ms".printf (
                            Pomodoro.Timestamp.to_milliseconds_uint (action_entry.command_execution_time));
                    }
                }

                entry.notify.connect (this.on_selected_entry_notify);
            }

            this.selected_entry = entry;
        }

        private void queue_update_contents ()
        {
            if (this.update_contents_id == 0) {
                this.update_contents_id = this.add_tick_callback (() => {
                    this.update_contents_id = 0;
                    this.update_contents ();

                    return GLib.Source.REMOVE;
                });
            }
        }

        private void update_stack_visible_child ()
        {
            var model = (Gtk.SingleSelection) this.listview.model;
            var n_items = model != null ? model.get_n_items () : 0U;
            var visible_child_name = n_items == 0U ? "placeholder" : "content";

            if (this.stack.visible_child_name != visible_child_name)
            {
                if (visible_child_name == "content") {
                    this.update_contents ();
                }

                this.stack.visible_child_name = visible_child_name;
            }
        }

        private void on_items_changed (GLib.ListModel model,
                                       uint           position,
                                       uint           removed,
                                       uint           added)
        {
            this.update_stack_visible_child ();
        }

        private void on_selection_changed (uint position,
                                           uint n_items)
        {
            this.update_contents ();
        }

        private void on_selected_entry_notify ()
        {
            this.queue_update_contents ();
        }

        [GtkCallback]
        private void setup_list_item (GLib.Object object)
        {
            var list_item = (Gtk.ListItem) object;
            list_item.child = new Pomodoro.SidebarRow ();
        }

        [GtkCallback]
        private void bind_list_item (GLib.Object object)
        {
            var list_item = (Gtk.ListItem) object;
            var entry = (Pomodoro.LogEntry) list_item.item;
            var row = (Pomodoro.SidebarRow?) list_item.child;

            if (row == null) {
                return;
            }

            if (entry is Pomodoro.EventLogEntry) {
                var event_entry = (Pomodoro.EventLogEntry) entry;
                row.icon_name = get_event_icon_name (event_entry.event_name);
            }

            if (entry is Pomodoro.ActionLogEntry)
            {
                var action_entry = (Pomodoro.ActionLogEntry) entry;
                row.icon_name = get_action_icon_name (action_entry.event_name);

                if (action_entry.command_error_message != null) {
                    row.parent.add_css_class ("error");
                }
                else {
                    action_entry.notify["command-error-message"].connect (
                        () => {
                            row.parent.add_css_class ("error");
                        });
                }

                if (action_entry.command_line != "" &&
                    action_entry.command_exit_code < 0 &&
                    action_entry.command_error_message == null)
                {
                    var spinner = new Gtk.Spinner ();
                    spinner.start ();

                    row.suffix = spinner;

                    action_entry.notify["command-exit-code"].connect (
                        (object, pspec) => {
                            spinner.stop ();
                        });
                }
            }

            row.title = entry.label;
        }

        public void select (ulong entry_id)
        {
            var model = (Gtk.SingleSelection?) this.listview.model;
            var n_items = model.n_items;

            for (var position = 0; position < n_items; position++)
            {
                var entry = (Pomodoro.LogEntry) model.get_item (position);

                if (entry.id == entry_id) {
                    model.set_selected (position);
                    break;
                }
            }
        }

        public override void dispose ()
        {
            if (this.listview != null) {
                this.listview.model.selection_changed.disconnect (this.on_selection_changed);
                this.listview.model.items_changed.disconnect (this.on_items_changed);
            }

            this.logger = null;

            base.dispose ();
        }
    }
}
