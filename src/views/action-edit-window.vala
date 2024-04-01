namespace Pomodoro
{
    private Pomodoro.Expression? ensure_operation (Pomodoro.Expression? expression)
    {
        return (expression is Pomodoro.Operation)
            ? expression
            : new Pomodoro.Operation (Pomodoro.Operator.AND, expression);
    }


    private class EventRow : Adw.ActionRow
    {
        public string event_name { get; construct; }

        construct
        {
            var remove_button = new Gtk.Button ();
            remove_button.icon_name = "window-close-symbolic";
            remove_button.valign = Gtk.Align.CENTER;
            remove_button.add_css_class ("flat");
            remove_button.clicked.connect (() => this.request_remove ());

            this.add_suffix (remove_button);
        }

        public EventRow (string event_name,
                         string title,
                         string subtitle)
        {
            GLib.Object (
                event_name: event_name,
                title: title,
                subtitle: subtitle
            );
        }

        public signal void request_remove ();
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/action-edit-window.ui")]
    public class ActionEditWindow : Adw.Window
    {
        public string? action_uuid { get; construct; }
        public bool creating { get; construct; }

        public Pomodoro.ActionTrigger trigger
        {
            get {
                return this.event_radio.active
                    ? Pomodoro.ActionTrigger.EVENT
                    : Pomodoro.ActionTrigger.CONDITION;
            }
            set {
                this.event_radio.active = value == Pomodoro.ActionTrigger.EVENT;
                this.condition_radio.active = value == Pomodoro.ActionTrigger.CONDITION;
            }
        }

        public bool enabled
        {
            get {
                return this.enabled_switch.active;
            }
            set {
                this.enabled_switch.active = value;
            }
        }

        public string display_name
        {
            get {
                return this.display_name_entryrow.text;
            }
            set {
                this.display_name_entryrow.text = value;
            }
        }

        public string command_line
        {
            get {
                return this.command_entryrow.text;
            }
            set {
                this.command_entryrow.text = value;
            }
        }

        public string enter_command_line
        {
            get {
                return this.enter_command_entryrow.text;
            }
            set {
                this.enter_command_entryrow.text = value;
            }
        }

        public string exit_command_line
        {
            get {
                return this.exit_command_entryrow.text;
            }
            set {
                this.exit_command_entryrow.text = value;
            }
        }

        public string working_directory
        {
            get {
                return this.working_directory_entryrow.text;
            }
            set {
                this.working_directory_entryrow.text = value;
            }
        }

        public bool use_subshell
        {
            get {
                return this.use_subshell_switchrow.active;
            }
            set {
                this.use_subshell_switchrow.active = value;
            }
        }

        public bool pass_input
        {
            get {
                return this.pass_input_switchrow.active;
            }
            set {
                this.pass_input_switchrow.active = value;
            }
        }

        public bool wait_for_completion
        {
            get {
                return this.wait_for_completion_switchrow.active;
            }
            set {
                this.wait_for_completion_switchrow.active = value;
            }
        }

        [GtkChild]
        private unowned Gtk.Button save_button;
        [GtkChild]
        private unowned Gtk.Switch enabled_switch;
        [GtkChild]
        private unowned Adw.EntryRow display_name_entryrow;
        [GtkChild]
        private unowned Gtk.CheckButton event_radio;
        [GtkChild]
        private unowned Gtk.CheckButton condition_radio;
        [GtkChild]
        private unowned Adw.PreferencesGroup events_group;
        [GtkChild]
        private unowned Pomodoro.ConditionGroupWidget condition_group_widget;
        [GtkChild]
        private unowned Gtk.MenuButton add_event_button;
        [GtkChild]
        private unowned Gtk.ToggleButton event_condition_button;
        [GtkChild]
        private unowned Adw.PreferencesGroup event_condition_group;
        [GtkChild]
        private unowned Pomodoro.ConditionGroupWidget event_condition_group_widget;
        [GtkChild]
        private unowned Adw.EntryRow working_directory_entryrow;
        [GtkChild]
        private unowned Adw.SwitchRow use_subshell_switchrow;
        [GtkChild]
        private unowned Adw.SwitchRow pass_input_switchrow;
        [GtkChild]
        private unowned Adw.SwitchRow wait_for_completion_switchrow;
        [GtkChild]
        private unowned Pomodoro.CommandEntryRow command_entryrow;
        [GtkChild]
        private unowned Pomodoro.CommandEntryRow enter_command_entryrow;
        [GtkChild]
        private unowned Pomodoro.CommandEntryRow exit_command_entryrow;
        [GtkChild]
        private unowned Adw.PreferencesGroup buttons_group;

        private Pomodoro.ActionManager? action_manager = null;
        private Pomodoro.EventProducer? event_producer = null;
        private unowned Gtk.ListBox?    events_listbox = null;

        public ActionEditWindow (string? action_uuid = null)
        {
            GLib.Object (
                action_uuid: action_uuid,
                creating: action_uuid == null
            );
        }

        static construct
        {
            install_action ("add-event", "s", (Gtk.WidgetActionActivateFunc) on_add_event);
        }

        construct
        {
            var text_widget = get_child_by_buildable_id (this.display_name_entryrow, "text")
                                                         as Gtk.Text;
            var events_listbox = get_child_by_buildable_id (this.events_group, "listbox")
                                                         as Gtk.ListBox;

            if (text_widget != null) {
                text_widget.max_length = 50;
            }
            else {
                GLib.warning ("Could not find text widget.");
            }

            if (events_listbox != null)
            {
                var placeholder_label = new Gtk.Label (_("No events specified yet."));
                placeholder_label.height_request = 50;
                placeholder_label.add_css_class ("dim-label");

                events_listbox.set_placeholder (placeholder_label);
            }
            else {
                GLib.warning ("Could not find events listbox.");
            }

            this.action_manager = new Pomodoro.ActionManager ();
            this.event_producer = new Pomodoro.EventProducer ();  // TODO: get from action manager

            this.add_event_button.menu_model = this.create_add_event_menu ();
            this.events_listbox = events_listbox;

            if (this.creating)
            {
                this.title = _("Create Custom Action");
                this.save_button.label = _("Cre_ate");
                this.buttons_group.visible = false;
            }

            this.populate ();
        }

        private void update_event_condition_visible ()
        {
            this.event_condition_group.visible = this.event_radio.active &&
                                                 this.event_condition_button.active;
        }

        private void populate ()
        {
            var action = this.action_uuid != null
                ? this.action_manager.model.lookup (this.action_uuid)
                : null;

            if (action == null) {
                action = new Pomodoro.EventAction (this.action_uuid);
            }

            this.enabled = action.enabled;
            this.display_name = action.display_name;

            if (action is Pomodoro.EventAction)
            {
                var event_action = (Pomodoro.EventAction) action;
                var condition = event_action.condition;
                var command = event_action.command;
                var row = this.events_group.get_first_child ();

                while (row != null)
                {
                    var next_sibling = row.get_next_sibling ();

                    if (row is Pomodoro.EventRow) {
                        this.events_group.remove (row);
                    }

                    row = next_sibling;
                }

                foreach (var event_name in event_action.event_names)
                {
                    row = this.create_event_row (event_name);

                    if (row != null) {
                        this.events_group.add (row);
                    }
                }

                this.trigger = Pomodoro.ActionTrigger.EVENT;
                this.event_condition_group_widget.expression = ensure_operation (condition);
                this.event_condition_button.active = condition != null;
                this.wait_for_completion = event_action.wait_for_completion;

                if (command != null) {
                    this.command_line = command.line;
                    this.working_directory = command.working_directory;
                    this.use_subshell = command.use_subshell;
                    this.pass_input = command.pass_input;
                }
            }

            if (action is Pomodoro.ConditionAction)
            {
                var condition_action = (Pomodoro.ConditionAction) action;
                var condition = action.condition;
                var enter_command = condition_action.enter_command;
                var exit_command = condition_action.exit_command;
                var any_command = enter_command != null ? enter_command : exit_command;

                this.trigger = Pomodoro.ActionTrigger.CONDITION;
                this.condition_group_widget.expression = ensure_operation (condition);

                if (enter_command != null) {
                    this.enter_command_line = enter_command.line;
                }

                if (exit_command != null) {
                    this.exit_command_line = exit_command.line;
                }

                if (any_command != null) {
                    this.working_directory = any_command.working_directory;
                    this.use_subshell = any_command.use_subshell;
                    this.pass_input = any_command.pass_input;
                }
            }

            this.update_event_condition_visible ();
        }

        private void save_action ()
        {
            var action = this.action_manager.model.create_action (this.action_uuid, this.trigger);
            action.enabled = this.enabled;
            action.display_name = this.display_name;

            if (action is Pomodoro.EventAction)
            {
                var event_action = (Pomodoro.EventAction) action;

                event_action.event_names = this.get_event_names ();
                event_action.condition = event_condition_button.active
                    ? this.event_condition_group_widget.expression
                    : null;
                event_action.wait_for_completion = this.wait_for_completion;

                event_action.command = new Pomodoro.Command (this.command_line);
                event_action.command.working_directory = this.working_directory;
                event_action.command.use_subshell = this.use_subshell;
                event_action.command.pass_input = this.pass_input;
            }

            if (action is Pomodoro.ConditionAction)
            {
                var condition_action = (Pomodoro.ConditionAction) action;

                condition_action.condition = this.condition_group_widget.expression;

                condition_action.enter_command = new Pomodoro.Command (this.enter_command_line);
                condition_action.enter_command.working_directory = this.working_directory;
                condition_action.enter_command.use_subshell = this.use_subshell;
                condition_action.enter_command.pass_input = this.pass_input;

                condition_action.exit_command = new Pomodoro.Command (this.exit_command_line);
                condition_action.exit_command.working_directory = this.working_directory;
                condition_action.exit_command.use_subshell = this.use_subshell;
                condition_action.exit_command.pass_input = this.pass_input;
            }

            this.action_manager.model.save_action (action);
        }

        private void delete_action ()
        {
            if (this.action_uuid != null) {
                this.action_manager.model.delete_action (this.action_uuid);
            }
        }

        private GLib.Menu create_add_event_menu ()
        {
            var menu = new GLib.Menu ();
            var sections = new GLib.HashTable<Pomodoro.EventCategory, GLib.Menu> (
                    GLib.direct_hash, GLib.direct_equal);

            foreach (var event_spec in this.event_producer.list_events ())
            {
                var section = sections.lookup (event_spec.category);

                if (section == null) {
                    var new_section = new GLib.Menu ();
                    sections.insert (event_spec.category, new_section);
                    section = new_section;
                }

                var section_item = new GLib.MenuItem (event_spec.display_name, null);
                section_item.set_action_and_target_value (
                                   "add-event",
                                   new GLib.Variant.string (event_spec.name));
                section.append_item (section_item);
            }

            Pomodoro.EventCategory.@foreach (
                (category) => {
                    var section = sections.lookup (category);

                    if (section != null) {
                        menu.append_section (category.get_label (), section);
                    }
                });

            return menu;
        }

        private void open_working_directory_chooser ()
        {
            var working_directory = this.working_directory != ""
                ? this.working_directory
                : GLib.Environment.get_home_dir ();

            var directory_filter = new Gtk.FileFilter ();
            directory_filter.add_mime_type ("inode/directory");

            var file_dialog = new Gtk.FileDialog ();
            file_dialog.title = _("Select Working Directory");
            file_dialog.modal = true;
            file_dialog.accept_label = _("_Select");
            file_dialog.default_filter = directory_filter;
            file_dialog.initial_file = File.new_for_path (working_directory);
            file_dialog.select_folder.begin (
                this,
                null,
                (obj, res) => {
                    GLib.File? file = null;

                    try {
                        file = file_dialog.select_folder.end (res);
                    }
                    catch (GLib.Error error) {
                        return;
                    }

                    if (file != null) {
                        this.working_directory = file.get_path ();
                    }
                });
        }

        [GtkCallback]
        public void on_cancel_button_clicked ()
        {
            this.close ();
        }

        [GtkCallback]
        public void on_save_button_clicked ()
        {
            this.save_action ();
            this.close ();
        }

        [GtkCallback]
        public void on_delete_button_clicked ()
        {
            this.delete_action ();
            this.close ();
        }

        [GtkCallback]
        public void on_trigger_radio_toggled (Gtk.CheckButton radio)
        {
            this.update_event_condition_visible ();
        }

        [GtkCallback]
        private void on_event_condition_button_toggled ()
        {
            this.update_event_condition_visible ();
        }

        [GtkCallback]
        private void on_event_condition_request_remove ()
        {
            this.event_condition_button.active = false;

            this.update_event_condition_visible ();
        }

        [GtkCallback]
        private void on_working_directory_button_clicked ()
        {
            this.open_working_directory_chooser ();
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.EventControllerKey event_controller,
                                     uint                   keyval,
                                     uint                   keycode,
                                     Gdk.ModifierType       state)
        {
            switch (keyval)
            {
                case Gdk.Key.Escape:
                    this.close ();
                    return true;
            }

            return false;
        }

        private string[] get_event_names ()
        {
            unowned var listbox = (Gtk.ListBox) this.events_listbox;
            unowned var child = listbox.get_first_child ();
            string[]    event_names = {};

            while (child != null)
            {
                if (child is EventRow)
                {
                    var row = (EventRow) child;

                    event_names += row.event_name;
                }

                child = child.get_next_sibling ();
            }

            return event_names;
        }

        private Adw.ActionRow? create_event_row (string event_name)
        {
            var event_spec = this.event_producer.find_event (event_name);

            if (event_spec == null) {
                GLib.warning ("Could not find event '%s'.", event_name);
                return null;
            }

            var row = new EventRow (event_name, event_spec.display_name, event_spec.description);
            row.request_remove.connect (this.events_group.remove);

            return row;
        }

        private void on_add_event (string        action_name,
                                   GLib.Variant? parameter)
        {
            if (parameter == null) {
                return;
            }

            var row = this.create_event_row (parameter.get_string ());

            if (row != null) {
                this.events_group.add (row);
            }
        }

        public override bool close_request ()
        {
            var cancelled = base.close_request ();

            if (!cancelled && this.creating) {
                this.delete_action ();
            }

            return cancelled;
        }

        public override void dispose ()
        {
            this.action_manager = null;
            this.event_producer = null;

            base.dispose ();
        }
    }
}

