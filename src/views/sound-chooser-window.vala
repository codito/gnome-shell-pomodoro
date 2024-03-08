namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/sound-chooser-window.ui")]
    public class SoundChooserWindow : Adw.Window
    {
        [CCode (notify = false)]
        public string uri {
            get {
                return this._uri;
            }
            set {
                if (this._uri != value) {
                    this._uri = value;

                    this.update_active_row ();

                    this.notify_property ("uri");
                }
            }
        }

        [CCode (notify = false)]
        public string event_id {
            get {
                return this._event_id;
            }
            set {
                if (this._event_id != value)
                {
                    this._event_id = value;

                    this.destroy_sound ();
                    this.ensure_sound ();

                    this.notify_property ("event-id");
                }
            }
        }

        public double volume { get; set; default = 1.0; }

        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild]
        private unowned Adw.PreferencesRow none_row;
        [GtkChild]
        private unowned Adw.PreferencesRow add_row;
        [GtkChild]
        private unowned Gtk.CheckButton radio_group;
        [GtkChild]
        private unowned Pomodoro.VolumeSlider volume_slider;

        private string                 _uri = "";
        private string                 _event_id = "";
        private unowned Gtk.ListBox?   list_box = null;
        private Pomodoro.Sound?        sound = null;
        private Pomodoro.SoundManager? sound_manager = null;
        private Adw.Toast?             toast = null;
        private int                    next_position = 1;
        private GLib.Cancellable?      cancellable = null;

        construct
        {
            this.sound_manager = new Pomodoro.SoundManager ();

            this.none_row.set_data<string> ("uri", "");

            this.list_box = (Gtk.ListBox) this.none_row.parent;
            this.list_box.activate_on_single_click = true;
            this.list_box.row_activated.connect (this.on_row_activated);

            this.bind_property ("volume",
                                this.volume_slider,
                                "value",
                                GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL);

            this.update_volume_slider_sensitivity ();
        }

        private void ensure_sound ()
        {
            if (this.sound != null) {
                return;
            }

            if (this._event_id != "" && this._event_id != null) {
                this.sound = new Pomodoro.AlertSound (this._event_id);
            }
            else {
                this.sound = new Pomodoro.BackgroundSound ();
            }

            this.sound.notify["error"].connect (this.on_sound_error);

            this.bind_property ("volume",
                                this.sound,
                                "volume",
                                GLib.BindingFlags.SYNC_CREATE);
        }

        private void destroy_sound ()
        {
            if (this.sound != null)
            {
                this.sound.notify["error"].disconnect (this.on_sound_error);

                this.sound.stop ();
                this.sound = null;
            }
        }

        private static inline string get_row_uri (Gtk.Widget row)
        {
            return row.get_data<string> ("uri");
        }

        private static inline void set_row_uri (Gtk.Widget row,
                                                string     uri)
        {
            row.set_data<string> ("uri", uri);
        }

        private unowned Gtk.Widget? get_row_by_uri (string uri)
        {
            unowned var row = (Gtk.Widget) this.none_row;

            while (row != null)
            {
                if (get_row_uri (row) == uri) {
                    return row;
                }

                row = row.get_next_sibling ();
            }

            return null;
        }

        private unowned Gtk.Widget? get_row_by_widget (Gtk.Widget widget)
        {
            unowned var row = widget.parent;

            while (row != null)
            {
                if (row is Adw.ActionRow) {
                    return row;
                }

                row = row.parent;
            }

            return null;
        }

        private void update_active_radio ()
        {
            for (var index = 0; index < this.next_position; index++)
            {
                var row = (Adw.ActionRow) this.list_box.get_row_at_index (index);
                var radio = (Gtk.CheckButton) row.activatable_widget;

                radio.active = get_row_uri (row) == this._uri;
            }
        }

        private void update_volume_slider_sensitivity ()
        {
            this.volume_slider.parent.sensitive = this._uri != "";
        }

        private void update_active_row ()
        {
            var existing_row = this.get_row_by_uri (this._uri);

            if (existing_row == null) {
                var label = GLib.File.new_for_uri (this._uri).get_basename ();

                this.add_preset_internal (this._uri, label, true);
            }
            else {
                this.update_active_radio ();
            }

            this.update_volume_slider_sensitivity ();

            if (this.sound != null) {
                this.sound.stop ();
            }
        }

        private void add_preset_internal (string uri,
                                          string label,
                                          bool   removable = false)
        {
            var radio = new Gtk.CheckButton ();
            radio.valign = Gtk.Align.CENTER;
            radio.group = this.radio_group;
            radio.active = this._uri == uri;
            radio.toggled.connect (this.on_radio_toggled);

            var row = new Adw.ActionRow ();
            row.use_markup = false;
            row.title = label;
            row.activatable = true;
            row.activatable_widget = radio;

            set_row_uri (row, uri);

            if (removable)
            {
                var remove_button = new Gtk.Button ();
                remove_button.icon_name = "window-close-symbolic";
                remove_button.valign = Gtk.Align.CENTER;
                remove_button.add_css_class ("image-button");
                remove_button.add_css_class ("flat");
                remove_button.clicked.connect (this.on_remove_button_clicked);
                row.add_suffix (remove_button);
            }

            row.add_suffix (radio);

            this.list_box.insert (row, this.next_position);

            this.next_position++;
        }

        private void open_file_chooser ()
        {
            this.ensure_sound ();

            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }

            this.cancellable = new GLib.Cancellable ();

            var file_filter = new Gtk.FileFilter ();

            foreach (var mime_type in this.sound.get_supported_mime_types ()) {
                file_filter.add_mime_type (mime_type);
            }

            var file_dialog = new Gtk.FileDialog ();
            file_dialog.title = _("Select Custom Sound");
            file_dialog.modal = true;
            file_dialog.accept_label = _("_Select");
            file_dialog.default_filter = file_filter;
            file_dialog.open.begin (
                this,
                this.cancellable,
                (obj, res) => {
                    GLib.File? file = null;

                    try {
                        file = file_dialog.open.end (res);
                    }
                    catch (GLib.Error error)
                    {
                        if (this.toast != null) {
                            this.toast.dismiss ();
                        }

                        return;
                    }

                    var uri = file != null ? file.get_uri () : "";
                    var existing_row = this.get_row_by_uri (uri);

                    if (existing_row == null && file != null) {
                        this.add_preset_internal (uri, file.get_basename (), true);
                    }

                    this.uri = uri;
                });
        }

        private void preview ()
        {
            if (this.toast != null) {
                this.toast.dismiss ();
                this.toast = null;
            }

            this.ensure_sound ();
            this.sound.uri = this._uri;

            if (this.sound.error == null) {
                this.sound.play ();
            }
        }

        private void on_row_activated (Gtk.ListBox    listbox,
                                       Gtk.ListBoxRow row)
        {
            if (row == this.add_row) {
                this.open_file_chooser ();
            }
            else {
                this.uri = get_row_uri (row);
                this.preview ();
            }
        }

        private void on_sound_error ()
        {
            var error = this.sound.error;

            if (this.toast != null) {
                this.toast.dismiss ();
                this.toast = null;
            }

            if (error != null) {
                this.toast = new Adw.Toast (error.message);
                this.toast_overlay.add_toast (this.toast);
            }
        }

        private void on_remove_button_clicked (Gtk.Button button)
        {
            var row = this.get_row_by_widget (button);

            this.remove_preset (get_row_uri (row));
        }

        [GtkCallback]
        private void on_radio_toggled (Gtk.CheckButton radio)
        {
            if (radio.active) {
                this.uri = get_row_uri (this.get_row_by_widget (radio));
            }
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

        public void add_preset (string uri,
                                string label)
        {
            this.add_preset_internal (uri, label);
        }

        public void remove_preset (string uri)
        {
            var row = this.get_row_by_uri (uri);

            if (row != null) {
                this.list_box.remove (row);
                this.next_position--;
            }

            if (this._uri == uri) {
                this.uri = "";
            }
        }

        public override void map ()
        {
            base.map ();

            this.sound_manager.inhibit_background_sound ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.destroy_sound ();

            this.sound_manager.uninhibit_background_sound ();
        }

        public override void dispose ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }

            this.list_box = null;
            this.sound_manager = null;

            base.dispose ();
        }
    }
}
