namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-panel-notifications.ui")]
    public class PreferencesPanelNotifications : Pomodoro.PreferencesPanel
    {
        private const uint[] IDLE_DELAY_CHOICES = { 15U, 30U, 60U, 120U, 180U, 300U, 0U };

        [GtkChild]
        private unowned Adw.SwitchRow announce_about_to_end_switchrow;
        [GtkChild]
        private unowned Adw.SwitchRow screen_overlay_switchrow;
        [GtkChild]
        private unowned Adw.ComboRow screen_overlay_lock_delay_comborow;
        [GtkChild]
        private unowned Adw.ComboRow screen_overlay_reopen_delay_comborow;

        private GLib.Settings?  settings;
        private ulong           settings_changed_id = 0;

        construct
        {
            this.settings = Pomodoro.get_settings ();
            this.settings_changed_id = settings.changed.connect (this.on_settings_changed);

            // Announcements
            this.settings.bind ("announce-about-to-end",
                                this.announce_about_to_end_switchrow,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);

            // Screen Overlay
            this.settings.bind ("screen-overlay",
                                this.screen_overlay_switchrow,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind_with_mapping (
                                "screen-overlay-lock-delay",
                                this.screen_overlay_lock_delay_comborow,
                                "selected",
                                GLib.SettingsBindFlags.DEFAULT,
                                idle_delay_get_mapping,
                                idle_delay_set_mapping,
                                null,
                                null);
            this.settings.bind_with_mapping (
                                "screen-overlay-reopen-delay",
                                this.screen_overlay_reopen_delay_comborow,
                                "selected",
                                GLib.SettingsBindFlags.DEFAULT,
                                idle_delay_get_mapping,
                                idle_delay_set_mapping,
                                null,
                                null);
            this.screen_overlay_switchrow.bind_property (
                                "active",
                                this.screen_overlay_lock_delay_comborow,
                                "sensitive",
                                GLib.BindingFlags.SYNC_CREATE);
            this.screen_overlay_switchrow.bind_property (
                                "active",
                                this.screen_overlay_reopen_delay_comborow,
                                "sensitive",
                                GLib.BindingFlags.SYNC_CREATE);
        }

        /**
         * Convert settings value to a choice.
         */
        private static bool idle_delay_get_mapping (GLib.Value   value,
                                                    GLib.Variant variant,
                                                    void*        user_data)
        {
            var seconds = variant.get_uint32 ();

            for (var choice_index = 0U; choice_index < IDLE_DELAY_CHOICES.length; choice_index++)
            {
                if (seconds == IDLE_DELAY_CHOICES[choice_index]) {
                    value.set_uint (choice_index);
                    return true;
                }
            }

            GLib.warning ("Could not map idle_delay to a choice");
            value.set_uint (30);

            return true;
        }

        /**
         * Convert choice to settings value.
         */
        private static GLib.Variant idle_delay_set_mapping (GLib.Value       value,
                                                            GLib.VariantType expected_type,
                                                            void*            user_data)
        {
            var choice_index = value.get_uint ();
            var choice_value = IDLE_DELAY_CHOICES[choice_index];

            return new GLib.Variant.uint32 (choice_value);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
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
