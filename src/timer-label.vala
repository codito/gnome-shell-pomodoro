
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

        construct
        {
            var timer = Pomodoro.Timer.get_default ();

            this.timer = timer;

            this.set_direction (Gtk.TextDirection.LTR);
        }

        private void on_timer_elapsed_notify ()
        {
            if (this.timer.state is Pomodoro.DisabledState)
            {
                this.minutes_label.text = "25";  // TODO: fetch pomodoro duration
                this.seconds_label.text = "00";  // TODO: fetch pomodoro duration
            }
            else {
                var remaining = (uint) double.max (Math.ceil (this.timer.remaining), 0.0);
                var minutes   = remaining / 60;
                var seconds   = remaining % 60;

                this.minutes_label.text = minutes.to_string ();
                this.seconds_label.text = "%02u".printf (seconds);
            }
        }

        /**
         * Mainly, we want to update the backdrop. To lower the contrast when timer isn't running.
         */
        private void update_css_classes ()
        {
            var is_stopped = this.timer.state is Pomodoro.DisabledState;
            var is_paused = this.timer.is_paused;
            var is_running = !(is_stopped || is_paused);

            if (is_running) {
                this.add_css_class ("timer-running");
            }
            else {
                this.remove_css_class ("timer-running");
            }

            if (is_paused) {
                this.add_css_class ("timer-paused");
            }
            else {
                this.remove_css_class ("timer-paused");
            }
        }

        private void on_timer_state_notify ()
        {
            this.update_css_classes ();
        }

        private void on_timer_is_paused_notify ()
        {
            this.update_css_classes ();
        }

        public void parser_finished (Gtk.Builder builder)
        {
            base.parser_finished (builder);

            this.minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.separator_label.set_direction (Gtk.TextDirection.LTR);
            this.seconds_label.set_direction (Gtk.TextDirection.LTR);

            this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);
            this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);

            this.on_timer_state_notify ();
            this.on_timer_elapsed_notify ();
            this.on_timer_is_paused_notify ();
        }
    }
}
