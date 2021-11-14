
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-label.ui")]
    public class TimerLabel : Gtk.Box, Gtk.Buildable
    {
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel seconds_label;

        private Pomodoro.Timer timer;
        private GLib.Settings  settings;
        private ulong          settings_changed_id = 0;

        construct
        {
            var timer = Pomodoro.Timer.get_default ();

            this.timer = timer;
            this.settings = Pomodoro.get_settings ().get_child ("preferences");
        }

        private void on_timer_elapsed_notify ()
        {
            uint remaining;
            uint minutes;
            uint seconds;

            if (this.timer.state is Pomodoro.DisabledState) {
                remaining = Pomodoro.PomodoroState.get_default_duration ();
            }
            else {
                remaining = (uint) double.max (Math.ceil (this.timer.remaining), 0.0);
            }

            minutes = remaining / 60;
            seconds = remaining % 60;

            this.minutes_label.text = minutes.to_string ();
            this.seconds_label.text = "%02u".printf (seconds);
        }

        public void parser_finished (Gtk.Builder builder)
        {
            base.parser_finished (builder);

            this.set_direction (Gtk.TextDirection.LTR);
            this.minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.separator_label.set_direction (Gtk.TextDirection.LTR);
            this.seconds_label.set_direction (Gtk.TextDirection.LTR);

            this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);

            this.on_timer_elapsed_notify ();

            this.settings_changed_id = this.settings.changed.connect (this.on_settings_changed);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            switch (key)
            {
                case "pomodoro-duration":
                    this.on_timer_elapsed_notify ();
                    break;

                default:
                    break;
            }
        }

        public override void dispose ()
        {
            if (this.settings_changed_id != 0) {
                this.settings.disconnect (this.settings_changed_id);
            }

            base.dispose ();
        }
    }
}
