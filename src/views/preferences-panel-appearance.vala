namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-panel-appearance.ui")]
    public class PreferencesPanelAppearance : Pomodoro.PreferencesPanel
    {
        [GtkChild]
        private unowned Adw.SwitchRow dark_theme_switchrow;
        [GtkChild]
        private unowned Adw.SwitchRow compact_view_switchrow;

        private GLib.Settings? settings = null;

        construct
        {
            this.settings = Pomodoro.get_settings ();

            this.settings.bind ("dark-theme",
                                this.dark_theme_switchrow,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("prefer-compact-size",
                                this.compact_view_switchrow,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
        }

        public override void dispose ()
        {
            this.settings = null;

            base.dispose ();
        }
    }
}
