
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-label.ui")]
    public class TimerLabel : Gtk.Box, Gtk.Buildable
    {
        public unowned Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            set {
                if (value == this._timer) {
                    return;
                }

                var is_ticking = this.timer_tick_id != 0;

                this.disconnect_signals ();

                this._timer = value;

                if (this.get_mapped ()) {
                    this.connect_signals ();
                }
            }
        }

        public unowned Pomodoro.SessionManager session_manager {
            get {
                return this._session_manager;
            }
            set {
                if (value == this._session_manager) {
                    return;
                }

                this._session_manager = value;

                this.timer = this._session_manager.timer;
            }
        }

        [GtkChild]
        private unowned Pomodoro.MonospaceLabel minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel seconds_label;

        private Pomodoro.SessionManager _session_manager;
        private Pomodoro.Timer          _timer;
        private ulong                   timer_state_changed_id = 0;
        private ulong                   timer_tick_id = 0;


        static construct
        {
            set_css_name ("timerlabel");
        }

        construct
        {
            this._session_manager = Pomodoro.SessionManager.get_default ();
            this._timer           = _session_manager.timer;
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
            if (this._timer.is_paused ()) {
                this.add_css_class ("blinking");
            }
            else {
                this.remove_css_class ("blinking");
            }

            if (!this._timer.is_started ()) {
                this.add_css_class ("timer-stopped");
            }
            else {
                this.remove_css_class ("timer-stopped");
            }
        }

        private void connect_signals ()
        {
            if (this.timer_tick_id == 0) {
                this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);
            }

            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
            }

            // TODO: monitor for next time-block duration when the timer is stopped
        }

        private void disconnect_signals ()
        {
            if (this.timer_tick_id != 0) {
                this._timer.disconnect (this.timer_tick_id);
                this.timer_tick_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        private void update_remaining_time (int64 timestamp = -1)
        {
            var remaining = this._timer.is_started ()
                ? this._timer.calculate_remaining (timestamp)
                : Pomodoro.State.POMODORO.get_default_duration ();
            // TODO: when stopped show duration of next time-block
            var remaining_uint = Pomodoro.Timestamp.to_seconds_uint (remaining);
            var minutes = remaining_uint / 60;
            var seconds = remaining_uint % 60;

            this.minutes_label.text = minutes.to_string ();
            this.seconds_label.text = "%02u".printf (seconds);
        }

        private void on_timer_tick (int64 timestamp)
        {
            this.update_remaining_time (timestamp);
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            this.update_remaining_time (timestamp);
            this.update_css_classes ();
        }

        public override void map ()
        {
            this.update_remaining_time ();
            this.update_css_classes ();

            this.connect_signals ();

            base.map ();
        }

        public override void unmap ()
        {
            this.disconnect_signals ();

            base.unmap ();
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
