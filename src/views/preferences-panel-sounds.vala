namespace Pomodoro
{
    private struct Preset
    {
        public string uri;
        public string label;
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-panel-sounds.ui")]
    public class PreferencesPanelSounds : Pomodoro.PreferencesPanel
    {
        private const Preset[] ALERT_PRESETS = {
            { "bell.ogg", N_("Bell") },
            { "loud-bell.ogg", N_("Loud Bell") },
        };
        private const Preset[] BACKGROUND_PRESETS = {
            { "clock.ogg", N_("Clock Ticking") },
            { "timer.ogg", N_("Timer Ticking") },
            { "birds.ogg", N_("Birds") },
        };

        [GtkChild]
        private unowned Gtk.Label pomodoro_finished_sound_label;
        [GtkChild]
        private unowned Gtk.Label break_finished_sound_label;
        [GtkChild]
        private unowned Gtk.Label background_sound_label;

        private GLib.Settings? settings  = null;
        private ulong          settings_changed_id = 0;

        construct
        {
            this.settings = Pomodoro.get_settings ();
            this.settings_changed_id = this.settings.changed.connect (this.on_settings_changed);

            this.update_sound_labels ();
        }

        private Pomodoro.SoundChooserWindow create_sound_chooser (string   title,
                                                                  string?  event_id,
                                                                  Preset[] presets)
        {
            var chooser = new Pomodoro.SoundChooserWindow ();
            chooser.title = title;
            chooser.event_id = event_id;
            chooser.transient_for = (Gtk.Window) this.get_root ();

            for (var index = 0; index < presets.length; index++) {
                chooser.add_preset (presets[index].uri, presets[index].label);
            }

            return chooser;
        }

        private string format_sound_label (string uri)
        {
            if (uri == "" || uri == null) {
                return _("None");
            }

            foreach (var preset in ALERT_PRESETS)
            {
                if (preset.uri == uri) {
                    return preset.label;
                }
            }

            foreach (var preset in BACKGROUND_PRESETS)
            {
                if (preset.uri == uri) {
                    return preset.label;
                }
            }

            return GLib.File.new_for_uri (uri).get_basename ();
        }

        private void update_sound_labels ()
        {
            this.pomodoro_finished_sound_label.label = this.format_sound_label (
                                        this.settings.get_string ("pomodoro-finished-sound"));
            this.break_finished_sound_label.label = this.format_sound_label (
                                        this.settings.get_string ("break-finished-sound"));
            this.background_sound_label.label = this.format_sound_label (
                                        this.settings.get_string ("background-sound"));
        }

        [GtkCallback]
        private void on_pomodoro_finished_sound_activated (Adw.ActionRow action_row)
        {
            var chooser = this.create_sound_chooser (action_row.title, "pomodoro-finished", ALERT_PRESETS);

            this.settings.bind ("pomodoro-finished-sound",
                                chooser,
                                "uri",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("pomodoro-finished-sound-volume",
                                chooser,
                                "volume",
                                GLib.SettingsBindFlags.DEFAULT);

            chooser.present ();
        }

        [GtkCallback]
        private void on_break_finished_sound_activated (Adw.ActionRow action_row)
        {
            var chooser = this.create_sound_chooser (action_row.title, "break-finished", ALERT_PRESETS);

            this.settings.bind ("break-finished-sound",
                                chooser,
                                "uri",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("break-finished-sound-volume",
                                chooser,
                                "volume",
                                GLib.SettingsBindFlags.DEFAULT);

            chooser.present ();
        }

        [GtkCallback]
        private void on_background_sound_activated (Adw.ActionRow action_row)
        {
            var chooser = this.create_sound_chooser (action_row.title, null, BACKGROUND_PRESETS);

            this.settings.bind ("background-sound",
                                chooser,
                                "uri",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("background-sound-volume",
                                chooser,
                                "volume",
                                GLib.SettingsBindFlags.DEFAULT);

            chooser.present ();
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            switch (key)
            {
                case "pomodoro-finished-sound":
                case "break-finished-sound":
                case "background-sound":
                    this.update_sound_labels ();
                    break;

                default:
                    break;
            }
        }

        public override void dispose ()
        {
            if (this.settings_changed_id != 0) {
                this.settings.disconnect (this.settings_changed_id);
                this.settings_changed_id = 0;
            }

            this.settings = null;

            base.dispose ();
        }
    }
}
