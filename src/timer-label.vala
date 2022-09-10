
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
        // private GLib.Settings  settings;
        // private ulong          settings_changed_id = 0;
        private ulong          timer_elapsed_id = 0;
        private ulong          timer_notify_state_id = 0;
        private ulong          timer_notify_is_paused_id = 0;

        construct
        {
            var timer = Pomodoro.Timer.get_default ();

            this.timer = timer;
            // this.settings = Pomodoro.get_settings ().get_child ("preferences");
        }

        private void set_default_direction_ltr ()
        {
            this.set_direction (Gtk.TextDirection.LTR);
            this.minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.separator_label.set_direction (Gtk.TextDirection.LTR);
            this.seconds_label.set_direction (Gtk.TextDirection.LTR);
        }

        private void update_css_classes ()
        {
            if (this.timer.is_running ()) {
                this.add_css_class ("timer-running");
            }
            else {
                this.remove_css_class ("timer-running");
            }

            if (this.timer.is_paused ()) {
                this.add_css_class ("timer-paused");
            }
            else {
                this.remove_css_class ("timer-paused");
            }

            if (!this.timer.is_started ()) {
                this.add_css_class ("timer-stopped");
            }
            else {
                this.remove_css_class ("timer-stopped");
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_elapsed_id != 0) {
                this.timer.disconnect (this.timer_elapsed_id);
                this.timer_elapsed_id = 0;
            }

            if (this.timer_notify_state_id != 0) {
                this.timer.disconnect (this.timer_notify_state_id);
                this.timer_notify_state_id = 0;
            }

            if (this.timer_notify_is_paused_id != 0) {
                this.timer.disconnect (this.timer_notify_is_paused_id);
                this.timer_notify_is_paused_id = 0;
            }

            // if (this.settings_changed_id != 0) {
            //     this.settings.disconnect (this.settings_changed_id);
            //     this.settings_changed_id = 0;
            // }
        }

        private void on_timer_elapsed_notify ()
        {
            var remaining = Pomodoro.Timestamp.to_seconds_uint (
                this.timer.is_started ()
                ? this.timer.calculate_remaining ()
                : Pomodoro.State.POMODORO.get_default_duration ());

            var minutes = remaining / 60;
            var seconds = remaining % 60;

            this.minutes_label.text = minutes.to_string ();
            this.seconds_label.text = "%02u".printf (seconds);
        }

        private void on_timer_state_notify ()
        {
            this.update_css_classes ();
        }

        private void on_timer_is_paused_notify ()
        {
            this.update_css_classes ();
        }

        // private void on_settings_changed (GLib.Settings settings,
        //                                   string        key)
        // {
        //     switch (key)
        //     {
        //         case "pomodoro-duration":
        //             this.on_timer_elapsed_notify ();
        //             break;
        //
        //         default:
        //             break;
        //     }
        // }

        public override void map ()
        {
            this.on_timer_elapsed_notify ();

            base.map ();

            // TODO
            // if (this.timer_elapsed_id == 0) {
            //     this.timer_elapsed_id = this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);
            // }

            // TODO
            // if (this.timer_notify_state_id == 0) {
            //     this.timer_notify_state_id = this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            // }

            // TODO
            // if (this.timer_notify_is_paused_id == 0) {
            //     this.timer_notify_is_paused_id = this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);
            // }

            // if (this.settings_changed_id == 0) {
            //     this.settings_changed_id = this.settings.changed.connect (this.on_settings_changed);
            // }
        }

        public override void unmap ()
        {
            base.unmap ();

            this.disconnect_signals ();
       }

        public override void realize ()
        {
            this.set_default_direction_ltr ();

            base.realize ();
        }

        public override void dispose ()
        {
            this.disconnect_signals ();

            base.dispose ();
        }
    }
}
