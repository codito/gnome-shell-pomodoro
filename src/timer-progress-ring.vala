namespace Pomodoro
{
    public class TimerProgressRing : Pomodoro.ProgressRing
    {
        public unowned Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            set {
                if (value == this._timer) {
                    return;
                }

                this.disconnect_signals ();

                this._timer = value;

                if (this.get_mapped ()) {
                    this.connect_signals ();
                }
            }
        }

        private Pomodoro.Timer _timer;
        private ulong          timer_state_changed_id = 0;
        private uint           timeout_id = 0;
        private uint           timeout_interval = 0;

        construct
        {
            this._timer = Pomodoro.Timer.get_default ();
        }

        private uint calculate_timeout_interval ()
        {
            var perimeter = (int64) Math.ceil (
                    2.0 * Math.PI * double.min (this.get_width (), this.get_height ()));

            return Pomodoro.Timestamp.to_milliseconds_uint (this._timer.duration / (2 * perimeter));
        }

        private void start_timeout ()
        {
            var timeout_interval = uint.max (this.calculate_timeout_interval (), 50);

            if (this.timeout_interval != timeout_interval) {
                this.timeout_interval = timeout_interval;
                this.stop_timeout ();
            }

            if (this.timeout_id == 0) {
                this.timeout_id = GLib.Timeout.add (this.timeout_interval, () => {
                    this.queue_draw_highlight ();

                    return GLib.Source.CONTINUE;
                });
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.TimerProgressRing.on_timeout");
            }
        }

        private void stop_timeout ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this._timer.is_running ()) {
                this.start_timeout ();
            }
            else {
                this.stop_timeout ();
            }

            if (this._timer.is_started ()) {
                this.fade_in ();
            }
            else {
                this.fade_out ();
            }

            this.queue_draw ();
        }

        private void connect_signals ()
        {
            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
            }

            if (this._timer.is_running ()) {
                this.start_timeout ();
            }
        }

        private void disconnect_signals ()
        {
            this.stop_timeout ();

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        public override double resolve_value (int64 monotonic_time)
        {
            var timestamp = this._timer.get_current_time (monotonic_time);

            return this._timer.is_started ()
                ? this._timer.calculate_progress (timestamp)
                : double.NAN;
        }

        public override void map ()
        {
            base.map ();

            this.connect_signals ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.disconnect_signals ();
        }

        public override void dispose ()
        {
            this.disconnect_signals ();

            base.dispose ();
        }
    }
}
