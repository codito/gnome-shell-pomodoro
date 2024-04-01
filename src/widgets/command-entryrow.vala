namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/command-entryrow.ui")]
    public class CommandEntryRow : Adw.EntryRow
    {
        public bool use_subshell
        {
            get {
                return this._use_subshell;
            }
            set {
                this._use_subshell = value;

                this.update ();
            }
        }

        private bool                 _use_subshell = false;
        private Pomodoro.Command     _command = null;
        private unowned Gtk.Image    edit_icon = null;
        private unowned Gtk.Text?    text_widget = null;
        private bool                 text_changed = false;

        construct
        {
            this.text_widget = get_child_by_buildable_id (this.child, "text") as Gtk.Text;
            this.edit_icon = get_child_by_buildable_id (this.child, "edit_icon") as Gtk.Image;

            if (this.text_widget != null)
            {
                this.text_widget.max_length = 500;
                this.text_widget.state_flags_changed.connect (this.on_text_widget_state_flags_changed);
                this.text_widget.changed.connect (this.on_text_widget_changed);
            }
            else {
                GLib.warning ("Could not find text widget.");
            }

            if (this.edit_icon == null) {
                GLib.warning ("Could not find edit icon.");
            }
        }

        private void insert_at_cursor (string text)
        {
            var initial_position = this.cursor_position;
            var position = initial_position;

            this.do_insert_text (text, text.length, ref position);

            if (position != initial_position) {
                this.set_position (position);
            }
        }

        private void update ()
        {
            if (this._command == null) {
                this._command = new Pomodoro.Command (this.text);
                this._command.use_subshell = this._use_subshell;
            }
            else {
                this._command.line = this.text;
                this._command.use_subshell = this._use_subshell;
            }

            try {
                if (this._command.line != "") {
                    this._command.validate ();
                }

                if (this.edit_icon != null) {
                    this.edit_icon.icon_name = "document-edit-symbolic";
                }

                this.tooltip_text = "";
                this.remove_css_class ("error");
            }
            catch (Pomodoro.CommandError error)
            {
                if (this.edit_icon != null) {
                    this.edit_icon.icon_name = "dialog-warning-symbolic";
                }

                this.tooltip_text = error.message;
                this.add_css_class ("error");
            }

            this.text_changed = false;
        }

        [GtkCallback]
        private void on_insert_variable_popover_selected (string variable_name,
                                                          string variable_format_name)
        {
            var variable_display_name = to_camel_case (variable_name);
            var variable_format_display_name = to_camel_case (variable_format_name);

            this.insert_at_cursor (variable_format_display_name != ""
                ? "${%s:%s}".printf (variable_display_name, variable_format_display_name)
                : "${%s}".printf (variable_display_name));
        }

        private void on_text_widget_state_flags_changed (Gtk.Widget     widget,
                                                         Gtk.StateFlags previous_state_flags)
        {
            var focused = Gtk.StateFlags.FOCUS_WITHIN in widget.get_state_flags ();

            if (!focused && this.text_changed) {
                this.update ();
            }
            else if (focused)
            {
                this.text_changed = true;

                this.remove_css_class ("error");
                this.tooltip_text = "";
            }
        }

        private void on_text_widget_changed (Gtk.Editable editable)
        {
            this.text_changed = true;
        }

        public override void dispose ()
        {
            if (this.text_widget != null) {
                this.text_widget.state_flags_changed.disconnect (this.on_text_widget_state_flags_changed);
                this.text_widget.changed.disconnect (this.on_text_widget_changed);
                this.text_widget = null;
            }

            this._command = null;
            this.edit_icon = null;

            base.dispose ();
        }
    }
}
