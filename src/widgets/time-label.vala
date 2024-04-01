namespace Pomodoro  // TODO: rename file to "time-label.vala"
{
    public sealed class TimeLabel : Gtk.Widget
    {
        // public unowned Pomodoro.Timer timer {
        //     get {
        //         return this._timer;
        //     }
        //     construct {
        //         this._timer = Pomodoro.Timer.get_default ();
        //     }
        // }

        public int64 timestamp {
            get {
                return this._timestamp;
            }
            set {
                this._timestamp = value;

                this.update_label ();
            }
        }

        public float xalign {
            get {
                return this.label.xalign;
            }
            set {
                this.label.xalign = value;
            }
        }

        // private Pomodoro.Timer          _timer;
        private int64                   _timestamp = Pomodoro.Timestamp.UNDEFINED;
        // private ulong                   timer_state_changed_id = 0;
        // private ulong                   timer_tick_id = 0;
        private Gtk.Label?              label;

        construct
        {
            this.label = new Gtk.Label (null);
            this.label.ellipsize = Pango.EllipsizeMode.END;
            this.label.single_line_mode = true;
            this.label.wrap = false;
            this.label.set_parent (this);
        }

        // private void connect_signals ()
        // {
        //     if (this.timer_tick_id == 0) {
        //         this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);
        //     }

        //     if (this.timer_state_changed_id == 0) {
        //         this.timer_state_changed_id = this._timer.state_changed.connect_after (this.on_timer_state_changed);
        //     }
        // }

        // private void disconnect_signals ()
        // {
        //     if (this.timer_tick_id != 0) {
        //         this._timer.disconnect (this.timer_tick_id);
        //         this.timer_tick_id = 0;
        //     }

        //     if (this.timer_state_changed_id != 0) {
        //         this._timer.disconnect (this.timer_state_changed_id);
        //         this.timer_state_changed_id = 0;
        //     }
        // }


        // private void on_timer_tick (int64 timestamp)
        // {
            // TODO:

        //     this.update_label (timestamp);
        // }

        // private void on_timer_state_changed (Pomodoro.TimerState current_state,
        //                                      Pomodoro.TimerState previous_state)
        // {
            // var timestamp = this._timer.get_last_tick_time ();
        //     var timestamp = this._timer.get_last_state_changed_time ();

        //     this.update_label (timestamp);

            // TODO: if timer is not running and label is mapped, schedule update every 10s

            // if (this.get_mapped ()) {
            //     this.queue_resize ();
            // }
        // }

        private string format_timestamp ()  // int64 timestamp)
        {
            if (this._timestamp < 0) {
                return "";
            }

            // var timer = Pomodoro.Timer.get_default ();
            // var interval = timer.get_last_tick_time () - timestamp;
            // var seconds = (uint) Pomodoro.round_seconds (Pomodoro.Timestamp.to_seconds (interval));

            // return _("%us ago").printf (seconds);
            // return Pomodoro.format_time (seconds);

            var seconds = this._timestamp / Pomodoro.Interval.SECOND;
            // var microseconds = timestamp % Pomodoro.Interval.SECOND;
            var datetime = (new GLib.DateTime.from_unix_utc (seconds)).to_local ();

            // TODO: include days ago
            return datetime.format ("%H:%M");
        }

        /*
        // TODO: move it to utils
        private inline string format_time (int64 timestamp)
        {
            // var unit = 5 * Pomodoro.Interval.SECOND;
            var interval = timestamp - this._timestamp;
            // var interval = ((timestamp - this._timestamp) / unit) * unit;
            var seconds = Pomodoro.Timestamp.to_seconds_uint (interval);

            if (seconds > 3600) {
                var hours = seconds / 3600;
                var minutes = seconds % 3600;

                return _("%u hours %u minutes ago").printf (hours, minutes);

                // TODO: just show the time
                // return _("%u:%u minutes ago").printf (hours, minutes);
            }
            else if (seconds > 60) {
                var minutes = seconds / 60;
                seconds = seconds % 60;

                // TODO: use ngettext
                return _("%u minutes %u seconds ago").printf (minutes, seconds);
            }
            else {
                // TODO: use ngettext
                return _("%u seconds ago").printf (seconds);
            }
        }
        */

        private void update_label (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            // if (Pomodoro.Timestamp.is_undefined (timestamp)) {
            //     timestamp = this._timer.get_last_tick_time ();
            // }

            this.label.label = this.format_timestamp ();
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }


        /**
         * Estimate size.
         *
         * Interpolate between two children and with-hours / without-hours.
         */
        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            this.label.measure (orientation,
                                for_size,
                                out minimum,
                                out natural,
                                out minimum_baseline,
                                out natural_baseline);
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var allocation = Gtk.Allocation ();

            this.label.measure (
                              Gtk.Orientation.VERTICAL,
                              height,
                              null,
                              out allocation.height,
                              null,
                              null);
            this.label.measure (
                              Gtk.Orientation.HORIZONTAL,
                              -1,
                              null,
                              out allocation.width,
                              null,
                              null);

            switch (this.halign)
            {
                case Gtk.Align.START:
                    allocation.x = 0;
                    break;

                case Gtk.Align.END:
                    allocation.x = width - allocation.width;
                    break;

                case Gtk.Align.CENTER:
                case Gtk.Align.FILL:
                    allocation.x = (width - allocation.width) / 2;
                    break;

                default:
                    assert_not_reached ();
            }

            allocation.y = (height - allocation.height) / 2;

            this.label.allocate_size (allocation, baseline);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.label, snapshot);
        }

        // public override void map ()
        // {
        //     this.on_timer_state_changed (this._timer.state, this._timer.state);
        //     this.connect_signals ();

        //     base.map ();
        // }

        // public override void unmap ()
        // {
        //     this.disconnect_signals ();

        //     base.unmap ();
        // }

        public override void dispose ()
        {
            if (this.label != null) {
                this.label.unparent ();
                this.label = null;
            }

            // this._timer = null;

            base.dispose ();
        }
    }
}
