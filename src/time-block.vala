using GLib;


namespace Pomodoro
{
    public class TimeBlock : GLib.InitiallyUnowned
    {
        public Pomodoro.State state { get; construct; default = Pomodoro.State.UNDEFINED; }
        public Pomodoro.Source source { get; construct; default = Pomodoro.Source.UNDEFINED; }
        public weak Pomodoro.Session session { get; set; }

        public int64 start_time {
            get {
                return this._start_time;
            }
            set {
                if (value < this._end_time) {
                    this.set_time_range (value, this._end_time);
                }
                else {
                    // TODO: log warning that change of `start-time` will affect `end-time`
                    this.set_time_range (value, value);
                }
            }
        }

        public int64 end_time {
            get {
                return this._end_time;
            }
            set {
                if (value >= this._start_time) {
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
        public int64 duration {
            get {
                return this._end_time - this._start_time;
            }
            set {
                this.set_time_range (this._start_time, this._start_time + value);
            }
        }

        protected GLib.SList<Pomodoro.Gap> gaps = null;
        protected int64                    _start_time = Pomodoro.Timestamp.MIN;
        protected int64                    _end_time = Pomodoro.Timestamp.MAX;
        private   int                      changed_freeze_count = 0;
        private   bool                     changed_is_pending = false;


        public TimeBlock (Pomodoro.State  state = Pomodoro.State.UNDEFINED,
                          Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
        {
            GLib.Object (
                state: state,
                source: source
            );
        }

        public TimeBlock.with_start_time (int64           start_time,
                                          Pomodoro.State  state = Pomodoro.State.UNDEFINED,
                                          Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
        {
            GLib.Object (
                state: state,
                source: source
            );

            this.set_time_range (
                start_time,
                Pomodoro.Timestamp.add (start_time, state.get_default_duration ())
            );
        }

        private void emit_changed ()
        {
            if (this.changed_freeze_count > 0) {
                this.changed_is_pending = true;
            }
            else {
                this.changed_is_pending = false;
                this.changed ();
            }
        }

        /**
         * Increases the freeze count on this.
         */
        public void freeze_changed ()
        {
            this.changed_freeze_count++;
        }

        /**
         * Decrease the freeze count on this.
         */
        public void thaw_changed ()
        {
            this.changed_freeze_count--;

            if (this.changed_freeze_count == 0) {
                this.emit_changed ();
            }
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
            // TODO: supress changed signal until gaps and self are both changed
            debug ("TimeBlock.move_by(%lld)", offset);

            this.gaps.@foreach ((gap) => gap.move_by (offset));

            this.set_time_range (Pomodoro.Timestamp.add (this._start_time, offset),
                                 Pomodoro.Timestamp.add (this._end_time, offset));
        }

        public void move_to (int64 start_time)
        {
            this.move_by (Pomodoro.Timestamp.subtract (start_time, this._start_time));
        }

        // Note: result won't make sense if block has no `start`
        public int64 calculate_elapsed (int64 timestamp = -1)  // TODO: is it used?
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (this._start_time >= timestamp || this._start_time >= this._end_time) {
                return 0;
            }

            var range_start = this._start_time;
            var range_end   = int64.min (this._end_time, timestamp);
            var elapsed     = Pomodoro.Timestamp.subtract (range_end, range_start);

            this.gaps.@foreach ((gap) => {
                if (gap.end_time <= gap.start_time) {
                    return;
                }

                elapsed = Pomodoro.Timestamp.subtract (
                    elapsed,
                    Pomodoro.Timestamp.subtract (
                        gap.end_time.clamp (range_start, range_end),
                        gap.start_time.clamp (range_start, range_end)
                    )
                );
                range_start = int64.max (range_start, gap.end_time.clamp (range_start, range_end));
            });

            return elapsed;
        }

        // Note: result won't make sense if block has no `end`
        public int64 calculate_remaining (int64 timestamp = -1)  // TODO: is it used?
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (timestamp >= this._end_time || this._start_time >= this._end_time) {
                return 0;
            }

            var range_start = int64.max (this._start_time, timestamp);
            var range_end   = this._end_time;
            var remaining   = Pomodoro.Timestamp.subtract (range_end, range_start);

            this.gaps.@foreach ((gap) => {
                if (gap.end_time <= gap.start_time) {
                    return;
                }

                remaining = Pomodoro.Timestamp.subtract (
                    remaining,
                    Pomodoro.Timestamp.subtract (
                        gap.end_time.clamp (range_start, range_end),
                        gap.start_time.clamp (range_start, range_end)
                    )
                );
                range_start = int64.max (range_start, gap.end_time.clamp (range_start, range_end));
            });

            return remaining;
        }

        // Note: result won't make sense if block has no `start` or `end`
        public double calculate_progress (int64 timestamp = -1)  // TODO: is it used?
        {
            if (this._start_time < 0) {
                return 0.0;
            }

            var duration = this.duration;

            return duration > 0
                ? this.calculate_elapsed (timestamp) / duration
                : 0.0;
        }

        public void add_gap (Pomodoro.Gap gap)
        {
            gap.time_block = this;

            this.gaps.insert_sorted (gap, Pomodoro.TimeBlock.compare);

            // TODO:
            // - fix overlaps
            // - make routine to sort and normalize gaps on Gap.changed

            this.changed ();
        }

        public void remove_gap (Pomodoro.Gap gap)
        {
            gap.time_block = null;

            this.gaps.remove (gap);

            this.changed ();
        }

        // public Pomodoro.TimeBlock? get_last_gap ()
        // {
        //     unowned SList<Pomodoro.Gap> link = this.gaps.last ();
        //
        //     return link != null ? link.data : null;
        // }

        public void foreach_gap (GLib.Func<Pomodoro.Gap> func)
        {
            this.gaps.@foreach (func);
        }

        public bool has_started (int64 timestamp = -1)  // TODO: rename to should_start
        {
            if (this._start_time < 0) {
                return true;
            }

            ensure_timestamp (ref timestamp);

            return timestamp >= this._start_time;
        }

        public bool has_ended (int64 timestamp = -1)  // TODO: rename to should_end
        {
            if (this._end_time < 0) {
                return false;
            }

            ensure_timestamp (ref timestamp);

            return timestamp > this._end_time;
        }

        public static int compare (Pomodoro.TimeBlock a,
                                   Pomodoro.TimeBlock b)
        {
            return (int) (a.start_time > b.start_time) - (int) (a.start_time < b.start_time);
        }

        // TODO: Vala causes issues with overriding default handler for "changed" signal when generating vapi.
        //       Remove `handle_changed()` once we can override "changed" handler in Gap.changed.
        protected virtual void handle_changed ()
        {
            // XXX: session manages changed signal itself
            // if (this.session != null) {
            //     this.session.changed ();
            // }
        }

        public virtual signal void changed ()
        {
            this.handle_changed ();
        }
    }


    public class Gap : Pomodoro.TimeBlock
    {
        public new Pomodoro.State state {
            get {
                return this.time_block != null ? this.time_block.state : Pomodoro.State.UNDEFINED;
            }
            set {
                assert_not_reached ();
            }
        }

        public new weak Pomodoro.Session session {
            get {
                return this.time_block != null ? this.time_block.session : null;
            }
            set {
                assert_not_reached ();
            }
        }

        public weak Pomodoro.TimeBlock time_block { get; set; }


        public Gap (Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
        {
            GLib.Object (
                source: source
            );
        }

        public Gap.with_start_time (int64           start_time,
                                    Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
        {
            GLib.Object (
                source: source
            );

            this.set_time_range (start_time, this._end_time);
        }

        public override void handle_changed ()
        {
            if (this.time_block != null) {
                this.time_block.changed ();
            }
        }

        // TODO: causes error "no suitable method found to override" when generating vapi
        // public override void changed ()
        // {
        //     if (this.time_block != null) {
        //         this.time_block.changed ();
        //     }
        // }
    }
}
