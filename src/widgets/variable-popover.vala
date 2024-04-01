namespace Pomodoro
{
    private class VariableItem : GLib.Object
    {
        public string display_name {
            get {
                return this._display_name;
            }
        }

        public string name {
            get {
                return this.spec.name;
            }
        }

        public string description {
            get {
                return this.spec.description;
            }
        }

        public GLib.Type value_type {
            get {
                return this.spec.value_type;
            }
        }

        private Pomodoro.VariableSpec spec;
        private string                _display_name;

        public VariableItem (Pomodoro.VariableSpec spec)
        {
            this.spec = spec;
            this._display_name = to_camel_case (spec.name);
        }
    }


    private class FormatItem : GLib.Object
    {
        public string display_name {
            get {
                return this._display_name;
            }
        }

        public string name {
            get {
                return this._name;
            }
        }

        private string _display_name;
        private string _name;

        public FormatItem (string variable_format)
        {
            this._name = variable_format;
            this._display_name = to_camel_case (variable_format);
        }
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/variable-popover.ui")]
    public class VariablePopover : Gtk.Popover
    {
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.ListView variables_listview;
        [GtkChild]
        private unowned Gtk.ListView formats_listview;
        [GtkChild]
        private unowned Gtk.Label variable_name_label;
        [GtkChild]
        private unowned Gtk.Label variable_description_label;

        private Gtk.SingleSelection?                     variables_model = null;
        private Gtk.SingleSelection?                     formats_model = null;
        private static GLib.HashTable<GLib.Type, string> last_used_formats = null;

        construct
        {
            this.variables_model = new Gtk.SingleSelection (this.create_variables_model ());
            this.variables_model.autoselect = false;
            this.variables_model.can_unselect = true;
            this.variables_model.selection_changed.connect (this.on_variables_model_selection_changed);

            this.variables_listview.model = this.variables_model;

            this.reset ();
        }

        private string get_preferred_format (GLib.Type value_type)
        {
            string? format = null;

            // TODO prioritize selected format used in the command line over last used ones.

            if (last_used_formats == null) {
                last_used_formats = new GLib.HashTable<GLib.Type, string> (GLib.direct_hash, GLib.direct_equal);
            }
            else {
                format = last_used_formats.lookup (value_type);
            }

            if (format == null) {
                format = Pomodoro.get_default_value_format (value_type);
            }

            return ensure_string (format);
        }

        private uint index_format (string format_name)
        {
            var model = this.formats_model.model;
            var n_items = model.get_n_items ();

            for (var position = 0U; position < n_items; position++)
            {
                var item = (FormatItem) model.get_item (position);

                if (item.name == format_name) {
                    return position;
                }
            }

            return 0U;
        }

        private GLib.ListModel create_variables_model ()
        {
            var model = new GLib.ListStore (typeof (VariableItem));

            foreach (unowned var variable in Pomodoro.list_variables ())
            {
                model.append (new VariableItem (variable));
            }

            return model;
        }

        private GLib.ListModel create_formats_model (GLib.Type value_type)
        {
            var model = new GLib.ListStore (typeof (FormatItem));

            foreach (unowned var variable_format in Pomodoro.list_value_formats (value_type))
            {
                model.append (new FormatItem (variable_format));
            }

            return model;
        }

        public void reset ()
        {
            this.variables_model.unselect_item (this.variables_model.selected);
        }

        [GtkCallback]
        private string get_variable_display_name (GLib.Object? item)
        {
            var variable_item = (VariableItem?) item;

            return variable_item?.display_name;
        }

        [GtkCallback]
        private void setup_format_item (GLib.Object object)
        {
            var check_button = new Gtk.CheckButton ();
            check_button.add_css_class ("monospace");

            var list_item = (Gtk.ListItem) object;
            list_item.child = check_button;
        }

        [GtkCallback]
        private void bind_format_item (GLib.Object object)
        {
            var list_item = (Gtk.ListItem) object;
            var check_button = (Gtk.CheckButton) list_item.child;
            check_button.active = list_item.selected;

            var format_item = (FormatItem) list_item.item;
            format_item.bind_property ("display-name", check_button, "label", GLib.BindingFlags.SYNC_CREATE);

            var toggled_id = check_button.toggled.connect (
                () => {
                    if (check_button.active) {
                        this.formats_model.select_item (list_item.position, true);
                    }
                    else {
                        check_button.active = true;
                    }
                });
            var notify_selected_id = list_item.notify["selected"].connect (
                (obj, pspec) => {
                    check_button.active = list_item.selected;
                });

            list_item.set_data<ulong> ("toggled-id", toggled_id);
            list_item.set_data<ulong> ("notify-selected-id", notify_selected_id);
        }

        [GtkCallback]
        private void unbind_format_item (GLib.Object object)
        {
            var list_item = (Gtk.ListItem) object;
            var toggled_id = list_item.get_data<ulong> ("toggled-id");
            var notify_selected_id = list_item.get_data<ulong> ("notify-selected-id");

            list_item.child.disconnect (toggled_id);
            list_item.disconnect (notify_selected_id);
        }

        [GtkCallback]
        private void on_back_button_clicked ()
        {
            this.reset ();
        }

        [GtkCallback]
        private void on_insert_variable_button_clicked ()
        {
            var variable_item = (VariableItem?) this.variables_model.selected_item;
            var format_item = (FormatItem?) this.formats_model.selected_item;

            if (variable_item != null)
            {
                var variable_name = variable_item.name;
                var format_name = format_item != null ? format_item.name : "";

                if (format_name == Pomodoro.get_default_value_format (variable_item.value_type)) {
                    format_name = "";
                }

                this.selected (variable_name, format_name);
            }
        }

        private void on_formats_model_selection_changed ()
                                                         requires (last_used_formats != null)
        {
            var variable_item = (VariableItem?) this.variables_model.selected_item;
            var format_item = (FormatItem?) this.formats_model.selected_item;

            if (variable_item != null && format_item != null) {
                last_used_formats.insert (variable_item.value_type, format_item.name);
            }
        }

        private void on_variables_model_selection_changed (uint position,
                                                           uint n_items)
        {
            var variable_item = (VariableItem?) this.variables_model.selected_item;

            if (variable_item != null)
            {
                var formats_model = this.create_formats_model (variable_item.value_type);
                var preferred_format = this.get_preferred_format (variable_item.value_type);

                this.formats_model = new Gtk.SingleSelection (formats_model);
                this.formats_model.autoselect = true;
                this.formats_model.can_unselect = false;
                this.formats_model.select_item (this.index_format (preferred_format), true);
                this.formats_model.selection_changed.connect (this.on_formats_model_selection_changed);

                this.formats_listview.model = this.formats_model;
                this.formats_listview.visible = this.formats_model.n_items > 1;
                this.variable_name_label.label = variable_item.name;
                this.variable_description_label.label = variable_item.description;
                this.stack.visible_child_name = "details";
            }
            else {
                this.stack.visible_child_name = "list";
            }
        }

        public signal void selected (string variable_name,
                                     string variable_format_name)
        {
            this.visible = false;
        }

        public override void closed ()
        {
            this.reset ();
        }

        public override void dispose ()
        {
            if (this.variables_model != null) {
                this.variables_model.selection_changed.disconnect (this.on_variables_model_selection_changed);
                this.variables_model = null;
            }

            if (this.formats_model != null) {
                this.formats_model.selection_changed.disconnect (this.on_formats_model_selection_changed);
                this.formats_model = null;
            }

            base.dispose ();
        }
    }
}
