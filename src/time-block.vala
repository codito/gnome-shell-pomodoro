using GLib;


namespace Pomodoro
{
    public class TimeBlock : GLib.InitiallyUnowned
    {
        public Pomodoro.State state { get; construct; default = Pomodoro.State.UNDEFINED; }
        public Pomodoro.Source source { get; construct; default = Pomodoro.Source.UNDEFINED; }
        public unowned Pomodoro.Session session { get; set; }

        protected GLib.SList<Pomodoro.Gap> gaps = null;
        protected int64 _start_time = Pomodoro.Timestamp.MIN;
        protected int64 _end_time = Pomodoro.Timestamp.MAX;

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

        /**
         * `skipped` is used externally to mark a time block that shouldn't be counted
         */
        // TODO: skipped gaps shouldn't be counted
        // public bool skipped {
        //     get; set; default = false;
        // }

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
                this.changed ();
            }
        }

        public void move_by (int64 offset)
        {
            // TODO: supress changed signal until gaps and self are both changed

            this.gaps.@foreach ((gap) => gap.move_by (offset));

            this.set_time_range (Pomodoro.Timestamp.add (this._start_time, offset),
                                 Pomodoro.Timestamp.add (this._end_time, offset));
        }

        public void move_to (int64 start_time)
        {
            this.move_by (Pomodoro.Timestamp.subtract (start_time, this._start_time));
        }

        // Note: result won't make sense if block has no `start`
        public int64 calculate_elapsed (int64 timestamp = -1)
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
        public int64 calculate_remaining (int64 timestamp = -1)
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

        // TODO
        public void thaw_changed ()
        {

        }

        /**
         * Increases the freeze count on this.
         */
        public void freeze_changed ()
        {

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

        public bool has_started (int64 timestamp = -1)
        {
            if (this._start_time < 0) {
                return true;
            }

            ensure_timestamp (ref timestamp);

            return timestamp >= this._start_time;
        }

        public bool has_ended (int64 timestamp = -1)
        {
            if (this._end_time < 0) {
                return false;
            }

            ensure_timestamp (ref timestamp);

            return timestamp > this._end_time;
        }

        // /**
        //  * Whether time block should be included in metrics
        //  */
        // public bool is_significant ()
        // {
        //     if (this.state == Pomodoro.State.POMODORO && this.duration < Pomodoro.Interval.MINUTE) {
        //         return false;
        //     }
        //
        //     if (this.state == Pomodoro.State.BREAK && this.duration < 20 * Pomodoro.Interval.SECOND) {
        //         return false;
        //     }
        //
        //     return this.state != Pomodoro.State.UNDEFINED;
        // }

        public static int compare (Pomodoro.TimeBlock a,
                                   Pomodoro.TimeBlock b)
        {
            return (int) (a.start_time > b.start_time) - (int) (a.start_time < b.start_time);
        }

        // TODO: remove once we can override "changed" handler in Gap.changed
        protected virtual void handle_changed ()
        {
            if (this.session != null) {
                this.session.changed ();
            }
        }

        public virtual signal void changed ()
        {
            this.handle_changed ();
        }

        // /**
        //  * Return whether time block has bounds.
        //  */
        // public bool is_finite ()
        // {
        //     return this._start_time >= 0 && this._end_time >= 0;
        // }

        // /**
        //  * Return whether time block is missing bounds. It does not take into account children.
        //  */
        // public bool is_infinite ()
        // {
        //     return this._start_time < 0 || this._end_time < 0;
        // }

        // /**
        //  * Return whether time block has bounds.
        //  */
        // public bool has_bounds (bool include_children = false)
        // {
        //     if (this._start_time <= Pomodoro.Timestamp.MIN || this._end_time >= Pomodoro.Timestamp.MAX) {
        //         return false;
        //     }

        //     if (include_children) {
        //         var has_bounds = true;
        //
        //         this.children.@foreach ((child) => {
        //             has_bounds = has_bounds && child.has_bounds (true);
        //         });
        //
        //         return has_bounds;
        //     }
        //
        //     return true;
        // }

        // public bool is_scheduled (int64 timestamp = -1)
        // {
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp < this._start_time;
        // }

        // public bool is_finished (int64 timestamp = -1)
        // {
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp >= this._end_time;
        // }

        // public bool is_in_progress (int64 timestamp = -1)
        // {
        //     ensure_timestamp (ref timestamp);
        //
        //     return timestamp >= this._start_time && timestamp < this._end_time;
        // }
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
        public new unowned Pomodoro.Session session {
            get {
                return this.time_block != null ? this.time_block.session : null;
            }
            set {
                assert_not_reached ();
            }
        }
        public unowned Pomodoro.TimeBlock time_block { get; set; }

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


    // /**
    //  * Class describes an block of time - state, start and end time.
    //  * Blocks may have parent/child relationships. Currently its only used to define pauses, though class is kept
    //  * angnostic about it. A child block may exceed its parent time range. After a child block gets defined `end` time,
    //  * the parent block is update its `end` time.
    //  */
    // public class PomodoroTimeBlock : TimeBlock
    // {
    //     public PomodoroTimeBlock (Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
    //     {
    //         GLib.Object (
    //             source: source
    //         );
    //     }

    //     public PomodoroTimeBlock.with_start_time (int64           start_time,
    //                                               Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
    //     {
    //         GLib.Object (
    //             source: source
    //         );

    //         this.set_time_range (
    //             start_time,
    //             Pomodoro.Timestamp.add (start_time, state.get_default_duration ())
    //         );
    //     }

    //     public override Pomodoro.State to_state ()
    //     {
    //         return Pomodoro.State.POMODORO;
    //     }
    // }

    // public class BreakTimeBlock : TimeBlock
    // {
        // TODO: changing is_long_break should trigger changed signal
    //     public bool is_long_break { get; set; }

    //     public BreakTimeBlock (Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
    //     {
    //         GLib.Object (
    //             source: source
    //         );
    //     }

    //     public BreakTimeBlock.with_start_time (int64           start_time,
    //                                            Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
    //     {
    //         GLib.Object (
    //             source: source
    //         );

    //         this.set_time_range (
    //             start_time,
    //             Pomodoro.Timestamp.add (start_time, state.get_default_duration ())
    //         );
    //     }

    //     public override Pomodoro.State to_state ()
    //     {
    //         return Pomodoro.State.BREAK;
    //     }
    // }

    // public class UndefinedTimeBlock : TimeBlock
    // {
    //     public UndefinedTimeBlock (Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
    //     {
    //         GLib.Object (
    //             source: source
    //         );
    //     }

    //     public UndefinedTimeBlock.with_start_time (int64           start_time,
    //                                                Pomodoro.Source source = Pomodoro.Source.UNDEFINED)
    //     {
    //         GLib.Object (
    //             source: source
    //         );

    //         this.set_time_range (
    //             start_time,
    //             Pomodoro.Timestamp.add (start_time, state.get_default_duration ())
    //         );
    //     }

    //     public override Pomodoro.State to_state ()
    //     {
    //         return Pomodoro.State.UNDEFINED;
    //     }
    // }

    /*
    public class DisabledState : TimerState
    {
        construct
        {
            this.name = "null";
        }

        public DisabledState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            return new DisabledState.with_timestamp (this.timestamp) as TimerState;
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var elapsed = timestamp - this.timestamp;

            return elapsed < TIME_TO_RESET_SCORE ? score : 0.0;
        }
    }

    public class PomodoroState : TimerState
    {
        construct
        {
            this.name = "pomodoro";

            this.duration = (double) PomodoroState.get_default_duration ();
        }

        public PomodoroState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        //
        // Return duration of a pomodoro from settings
        //
        public static uint get_default_duration ()
        {
            return Pomodoro.get_settings ()
                                      .get_uint ("pomodoro-duration");
        }

        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            var score_limit = Pomodoro.get_settings ()
                                      .get_uint ("pomodoros-per-session");

            var min_long_break_score = double.max (score_limit * POMODORO_THRESHOLD,
                                                   score_limit - MISSING_SCORE_THRESHOLD);

            var next_state = score >= min_long_break_score
                    ? new LongBreakState.with_timestamp (timestamp) as TimerState
                    : new ShortBreakState.with_timestamp (timestamp) as TimerState;

            next_state.elapsed = double.max (this.elapsed - this.duration, 0.0);

            return next_state;
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var achieved_score = this.duration > 0.0
                    ? double.min (this.elapsed, this.duration) / this.duration
                    : 0.0;

            return this.duration <= MIN_POMODORO_TIME || this.elapsed >= MIN_POMODORO_TIME
                    ? score + achieved_score : score;
        }
    }

    public abstract class BreakState : TimerState
    {
        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            return new PomodoroState.with_timestamp (timestamp) as TimerState;
        }
    }

    public class ShortBreakState : BreakState
    {
        construct
        {
            this.name = "short-break";

            this.duration = (double) ShortBreakState.get_default_duration ();
        }

        public ShortBreakState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        //
        // Return duration of a short break from settings
        //
        public static uint get_default_duration ()
        {
            return Pomodoro.get_settings ()
                                      .get_uint ("short-break-duration");
        }
    }

    public class LongBreakState : BreakState
    {
        construct
        {
            this.name = "long-break";

            this.duration = (double) LongBreakState.get_default_duration ();
        }

        public LongBreakState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        //
        // Return duration of a long break from settings
        //
        public static uint get_default_duration ()
        {
            return Pomodoro.get_settings ()
                                      .get_uint ("long-break-duration");
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var short_break_duration = Pomodoro.get_settings ()
                                               .get_uint ("short-break-duration");
            var long_break_duration = this.duration;

            var min_elapsed =
                    short_break_duration +
                    (long_break_duration - short_break_duration) * SHORT_TO_LONG_BREAK_THRESHOLD;

            return this.elapsed >= min_elapsed || timestamp - this.timestamp >= min_elapsed
                    ? 0.0 : score;
        }
    }
    */
}
