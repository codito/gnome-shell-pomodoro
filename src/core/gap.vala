namespace Pomodoro
{
    public class Gap : GLib.InitiallyUnowned, Pomodoro.Schedulable
    {
        [CCode (notify = false)]
        public int64 start_time {
            get {
                return this._start_time;
            }
            set {
                if (this._start_time == value) {
                    return;
                }

                if (value < this._end_time || Pomodoro.Timestamp.is_undefined (this._end_time)) {
                    this.set_time_range (value, this._end_time);
                }
                else {
                    // TODO: log warning that change of `start-time` will affect `end-time`
                    this.set_time_range (value, value);
                }
            }
        }

        [CCode (notify = false)]
        public int64 end_time {
            get {
                return this._end_time;
            }
            set {
                if (this._end_time == value) {
                    return;
                }

                if (value >= this._start_time || Pomodoro.Timestamp.is_undefined (this._start_time)) {
                    this.set_time_range (this._start_time, value);
                }
                else {
                    // TODO: log warning that change of `end-time` will affect `start-time`
                    this.set_time_range (value, value);
                }
            }
        }

        /**
         * `duration` of a time block, including gaps
         */
        [CCode (notify = false)]
        public int64 duration {
            get {
                return Pomodoro.Timestamp.subtract (this._end_time, this._start_time);
            }
            set {
                if (Pomodoro.Timestamp.is_defined (this._start_time)) {
                    this.set_time_range (this._start_time,
                                         Pomodoro.Timestamp.add_interval (this._start_time, value));
                }
                else {
                    GLib.warning ("Can't change time-block duration without a defined start-time.");
                }
            }
        }

        public weak Pomodoro.TimeBlock time_block { get; set; }  // parent

        internal ulong              version = 0;
        internal Pomodoro.GapEntry? entry = null;

        private int64               _start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64               _end_time = Pomodoro.Timestamp.UNDEFINED;

        public Gap ()
        {
            GLib.Object ();
        }

        public Gap.with_start_time (int64 start_time)
        {
            GLib.Object ();

            this.set_time_range (start_time, this._end_time);
        }

        private void emit_changed ()
        {
            this.version++;

            this.changed ();
        }

        public void set_time_range (int64 start_time,
                                    int64 end_time)
        {
            var old_start_time = this._start_time;
            var old_end_time = this._end_time;
            var old_duration = this._end_time - this._start_time;
            var changed = false;

            this._start_time = start_time;
            this._end_time = end_time;

            if (this._start_time != old_start_time) {
                this.notify_property ("start-time");
                changed = true;
            }

            if (this._end_time != old_end_time) {
                this.notify_property ("end-time");
                changed = true;
            }

            if (this._end_time - this._start_time != old_duration) {
                this.notify_property ("duration");
            }

            if (changed) {
                this.emit_changed ();
            }
        }

        public void move_by (int64 offset)
        {
            var start_time = Pomodoro.Timestamp.is_defined (this._start_time)
                ? Pomodoro.Timestamp.add_interval (this._start_time, offset)
                : Pomodoro.Timestamp.UNDEFINED;
            var end_time = Pomodoro.Timestamp.is_defined (this._end_time)
                ? Pomodoro.Timestamp.add_interval (this._end_time, offset)
                : Pomodoro.Timestamp.UNDEFINED;

            this.set_time_range (start_time, end_time);
        }

        public void move_to (int64 start_time)
        {
            if (Pomodoro.Timestamp.is_undefined (this._start_time) &&
                Pomodoro.Timestamp.is_undefined (this._end_time))
            {
                this.set_time_range (start_time, this._end_time);
                return;
            }

            if (Pomodoro.Timestamp.is_undefined (this._start_time)) {
                GLib.warning ("Unable to move gap. Gap start-time is undefined.");
                return;
            }

            this.move_by (Pomodoro.Timestamp.subtract (start_time, this._start_time));
        }


        /*
         * Database
         */

        internal bool should_create_entry ()
        {
            return Pomodoro.Timestamp.is_defined (this.start_time);
        }

        internal bool should_update_entry ()
        {
            if (this.entry == null || this.entry.id == 0) {  // !this.entry.get_is_from_table ()) {
                return true;
            }

            return this.entry.version != this.version;
        }

        internal Pomodoro.GapEntry create_or_update_entry ()
                                                           requires (this.time_block.entry != null)
        {
            if (this.entry == null)
            {
                this.entry = new Pomodoro.GapEntry ();
                this.entry.repository = Pomodoro.Database.get_repository ();

                this.time_block.entry.bind_property ("id",
                                                     this.entry,
                                                     "time-block-id",
                                                     GLib.BindingFlags.SYNC_CREATE);
            }

            this.entry.start_time = this.start_time;
            this.entry.end_time = this.end_time;
            this.entry.version = this.version;

            return this.entry;
        }

        internal void unset_entry ()
        {
            this.entry = null;
        }


        /*
         * Signals
         */

        public signal void changed ();
    }
}
