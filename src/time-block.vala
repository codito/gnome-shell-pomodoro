/*
 * Copyright (c) 2011-2015 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    /* Minimum time in seconds for pomodoro to get scored. */
    internal const double MIN_POMODORO_TIME = 60.0;

    /* Minimum progress for pomodoro to be considered for a long break. Higer values means
       the timer is more strict about completing pomodoros. */
    internal const double POMODORO_THRESHOLD = 0.90;

    /* Acceptable score value that can be missed during cycle. */
    internal const double MISSING_SCORE_THRESHOLD = 0.50;

    /* Minimum progress for long break to get accepted. It's in reference to duration of a short break,
       or more precisely it's a ratio between duration of a short break and a long break. */
    internal const double SHORT_TO_LONG_BREAK_THRESHOLD = 0.50;


    // public enum Reason
    // {
    //     UNKNOWN = 0,
    //     TIMER = 1,
    //     USER = 2
    // }


    // /**
    //  * Pomodoro.Pause
    //  *
    //  * By a pause we referr to an undefined state within a time block.
    //  */
    // public struct Pause
    // {
    //     public int64 timestamp;
    //     public int64 duration = -1;  // -1 if it's ongoing

    //     public Pause (int64 timestamp)
    //                   requires (timestamp > 0)
    //     {
    //         this.timestamp = timestamp;
    //     }

        // public bool is_finished ()
        // {
        //     return this.duration >= 0;
        // }

    //     public void finish (int64 timestamp = Pomodoro.get_current_time ())
    //     {
    //         this.duration = int64.max (timestamp - this.timestamp, 0);
    //     }
    // }


    // /**
    //  * Pomodoro.TimeBlockType
    //  *
    //  * We operate within predefined time blocks / timer states. We treat UNDEFINED time blocks somewhat
    //  * similar to regular ones. It simplifies detection of idle time ("idle" in a sense that timer is not running).
    //  */
    // public enum TimeBlockType
    // {
    //     UNDEFINED = 0,  // aka stopped
    //     POMODORO = 1,
    //     SHORT_BREAK = 2,  // TODO: combine SHORT_BREAK and LONG_BREAK into BREAK?
    //     LONG_BREAK = 3
    // }


    // public enum TimeBlockStatus
    // {
    //     SCHEDULED = 0,
    //     STARTED = 1,
    //     ENDED = 2,
    //     CANCELED = 3
    // }


    // public delegate void ForeachTimeBlockFunc (Pomodoro.TimeBlock block);

    private void ensure_timestamp (ref int64 timestamp)
    {
        if (timestamp < 0) {
            timestamp = Pomodoro.get_current_time ();
        }
    }

    private enum TimeBlockConflict
    {
        KEEP_START = 0,
        KEEP_END = 1
    }

    // public errordomain TimeBlockError
    // {
    //     MISSING_BOUNDS
    // }

    private const int64 MIN_TIMESTAMP = int64.MIN;
    private const int64 MAX_TIMESTAMP = int64.MAX;


    /**
     * Pomodoro.TimeBlock
     *
     * Class describes an block of time - state, start and end time.
     * Blocks may have parent/child relationships. Currently its only used to define pauses, though class is kept
     * angnostic about it. A child block may exceed its parent time range. After a child block gets defined `end` time,
     * the parent block is update its `end` time.
     */
    public class TimeBlock : GLib.Object
    {
        // TODO !!!!! any change to a block should be propagated to parent blocks
        // TODO !!!!! use MIN_TIMESTAMP and MAX_TIMESTAMP instead of -1


        public Pomodoro.State state {
            get {
                return this._state;
            }
        }

        // -1 value refers to -Infinity
        public int64 start {
            get {
                return this._start;
            }
            set {
                this.set_range (value, this._end, Pomodoro.TimeBlockConflict.KEEP_START);

                // this._start = this._end >= 0
                //     ? int64.min (value, this._end)
                //     : value;

                // TODO: update this._duration
            }
        }

        // -1 value refers to Infinity
        public int64 end {
            get {
                return this._end;
            }
            set {
                this.set_range (this._start, value, Pomodoro.TimeBlockConflict.KEEP_END);

                // this._end = value >= 0
                //     ? int64.max (value, this._start)
                //     - 1;
                // TODO: update this._duration
            }
        }

        // Beware that `duration` has a few edge cases:
        //  - when time block is infinite (`end` < 0 or `start` < 0) it returns -1
        //  - when one of the child is infinite, it returns duration according to its `end` and not the childs
        public int64 duration {
            get {
                return this._start >= 0 && this._end >= 0
                    ? this._end - this._start
                    : -1;
            }
            set {
                // if (this._is_finalized) {
                //     return;
                // }

                if (this._start >= 0) {
                    this.set_range (this._start,
                                    this._start + value,
                                    Pomodoro.TimeBlockConflict.KEEP_START);
                }
                else if (this._end >= 0) {
                    this.set_range (this._end - value,
                                    this._end,
                                    Pomodoro.TimeBlockConflict.KEEP_END);
                }
                else {
                    GLib.warning ("Can't change TimeBlock.duration when both start and end are not defined");
                }
            }
        }

        public unowned Pomodoro.TimeBlock? parent {
            get {
                return this._parent;
            }
            set {
                if (this._parent != value) {
                    // TODO: unparent properly, connect/disconnect signals
                    this._parent = value;
                }
            }
        }

        // public Pomodoro.Event? start_event {
        //     get {
        //         return this._start_source;
        //     }
        // }

        // public Pomodoro.Event? end_event {
        //     get {
        //         return this._start_source;
        //     }
        // }

        // Gaps should be defined as a child of a state, with first item as most recent.
        // A gap should not extend the time of parent block, it will be capped if it does.
        private GLib.SList<Pomodoro.TimeBlock> children = null;
        private unowned Pomodoro.TimeBlock _parent = null;

        private Pomodoro.State  _state = State.UNDEFINED;
        private Pomodoro.Source _source = Source.OTHER;
        private int64           _start = -1;
        private int64           _end = -1;
        // private bool            _is_finalized = false;

        public TimeBlock (Pomodoro.State state = State.UNDEFINED,
                          int64          start = -1,
                          int64          end = -1)
        {
            // ensure_timestamp (ref start);

            this._state = state;

            this.set_range_internal (start, end, Pomodoro.TimeBlockConflict.KEEP_START);

            // this.children = null;
        }

        // construct
        // {
        //     if (this._timestamp == 0) {
        //         this._timestamp = Pomodoro.get_current_time ();
        //     }
        // }

        private void set_range_internal (int64                      start,
                                         int64                      end,
                                         Pomodoro.TimeBlockConflict on_conflict)
        {
            if (start >= 0 && end >= 0 && end < start) {
                if (on_conflict == Pomodoro.TimeBlockConflict.KEEP_START) {
                    end = start;
                }
                else {
                    start = end;
                }
            }

            this._start = start >= 0 ? start : -1;
            this._end = end >= 0 ? end : -1;
        }

        public void set_range (int64                      start,
                               int64                      end,
                               Pomodoro.TimeBlockConflict on_conflict = Pomodoro.TimeBlockConflict.KEEP_START)
        {
            // if (this._is_finalized) {
            //     return;
            // }

            var old_start = this._start;
            var old_end = this._end;
            var old_duration = this.duration;

            this.set_range_internal (start, end, on_conflict);

            if (this._start != old_start) {
                this.notify_property ("start");
            }

            if (this._end != old_end) {
                this.notify_property ("end");
            }

            if (this.duration != old_duration) {
                this.notify_property ("duration");
            }

            if (this._start != old_start || this._end != old_end) {
                this.changed_range ();
            }
        }

        // /**
        //  * Return whether time block has been finalized, which prevents from changes.
        //  */
        // public bool is_finalized ()
        // {
        //     return this._is_finalized;
        // }

        // /**
        //  * Return whether time block has bounds. It does not take into account children.
        //  */
        // public bool is_finite ()
        // {
        //     return this._start >= 0 && this._end >= 0;
        // }

        // /**
        //  * Return whether time block is missing bounds. It does not take into account children.
        //  */
        // public bool is_infinite ()
        // {
        //     return this._start < 0 || this._end < 0;
        // }

        /**
         * Return whether time block has bounds.
         */
        public bool has_bounds (bool include_children = false)
        {
            if (this._start < 0 || this._end < 0) {
                return false;
            }

            if (include_children) {
                var has_bounds = true;

                this.children.@foreach ((child) => {
                    has_bounds = has_bounds && child.has_bounds (true);
                });

                return has_bounds;
            }

            return true;
        }

        public bool has_started (int64 timestamp = -1)
        {
            if (this._start < 0) {
                return true;
            }

            ensure_timestamp (ref timestamp);

            return timestamp >= this._start;
        }

        public bool has_ended (int64 timestamp = -1)
        {
            if (this._end < 0) {
                return false;
            }

            ensure_timestamp (ref timestamp);

            return this._end <= timestamp;
        }

        // Note: result won't make sense if block has no `start`
        public int64 get_elapsed (int64 timestamp = -1)
        {
            if (this._start < 0) {
                return -1;
            }

            ensure_timestamp (ref timestamp);

            return int64.max (timestamp - this._start, 0);
        }

        // Note: result won't make sense if block has no `end`
        public int64 get_remaining (int64 timestamp = -1)
        {
            if (this._end < 0) {
                return -1;
            }

            ensure_timestamp (ref timestamp);

            return int64.max (this._end - timestamp, 0);
        }

        // Note: result won't make sense if block have no bounds
        public double get_progress (int64 timestamp = -1)
        {
            if (this._start < 0) {
                return 0.0;
            }

            // ensure_timestamp (ref timestamp);
            // if (timestamp < 0) {
            //     timestamp = Pomodoro.get_current_time ();
            // }

            var duration = this.duration;

            return duration > 0
                ? this.calculate_elapsed (timestamp) / duration
                : 0.0;
        }

        // /**
        //  * Return sum of childrens durations.
        //  */
        // public int64 get_children_duration ()
        // {
        //     int64 children_duration = 0;

        //     this.children.@foreach ((child) => {
                // TODO: handle overlapping children

        //         if (children_duration >= 0) {
        //             if (child.has_bounds ()) {
        //                 children_duration += child.duration;
        //             }
        //             else {
        //                 children_duration = -1;
        //             }
        //         }
        //     });

        //     return children_duration;
        // }

        // /**
        //  * Similar to .get_children_duration(), but counts elapsed time in case blocks have no `end`
        //  *
        //  * Return sum of childrens durations.
        //  */
        // public int64 get_children_elapsed (int64 timestamp = -1)
        // {
        //     int64 children_elapsed = 0;

        //     ensure_timestamp (ref timestamp);
            // if (timestamp < 0) {
            //     timestamp = Pomodoro.get_current_time ();
            // }

        //     this.children.@foreach ((child) => {
                // TODO: handle overlapping children

        //         if (children_elapsed >= 0 ) {
        //             children_elapsed += child.duration;
        //         }

        //         children_elapsed += child.get_elapsed (timestamp);
        //     });

        //     return children_elapsed;
        // }

        /**
         * Apply parent bounds
         */
        private void inherit_bounds ()
        {
            if (this._parent == null) {
                return;
            }

            // this.unfinalize ();

            var parent_start = this._parent.start;
            var parent_end = this._parent.end;

            this.set_range (
                parent_start >= 0
                    ? int64.max (this._start, parent_start)
                    : this._start,
                parent_end >= 0
                    ? (this._end >= 0 ? int64.min (this._end, parent_end) : parent_end)
                    : this._end
            );
        }



        // /**
        //  * TimeBlock.finalize()
        //  *
        //  * Finalization enforces that blocks have bounds and that there are no overlapping children.
        //  * It finializes children first. Parent bounds may be extended. Overlapping children will be adjusted
        //  * with KEEP_START policy.
        //  *
        //  * Any changes will mark block and its ancestors as unfinalized.
        //  */
        // public void finalize_1 () throws Pomodoro.TimeBlockError
        // {
        //     if (this._is_finalized) {
        //         return;
        //     }

        //     if (!this.has_bounds (false)) {
        //         throw new Pomodoro.TimeBlockError.MISSING_BOUNDS ("Block has no bounds");
        //     }

        //     var final_start = this._start;
        //     var final_end = this._end;

        //     this.children.@foreach ((child) => {
        //         try {
        //             child.finalize ();
        //         }
        //         catch (Pomodoro.TimeBlockError error) {
        //             error.message = "Child has no bounds";
        //             throw error;
        //         }

        //         final_start = int64.min (final_start, child.start);
        //         final_end = int64.max (final_end, child.end);
        //     });

        //     this.set_range (final_start, final_end);

        //     this._is_finalized = true;

        //     this.finalized ();
        // }

        // public void unfinalize ()
        // {
        //     this._is_finalized = false;

        //     if (this.parent != null) {
        //         this.parent.unfinalize ();
        //     }
        // }

        private static int compare (Pomodoro.TimeBlock a,
                                    Pomodoro.TimeBlock b)
        {
            return - ((int) (a.start > b.start) - (int) (a.start < b.start));  // in descending order
        }

        public void add_child (Pomodoro.TimeBlock child)
        {
            // this.unfinalize ();

            this.children.insert_sorted (child, this.compare);
        }

        public void remove_child (Pomodoro.TimeBlock child)
        {
            // this.unfinalize ();

            this.children.remove (child);
        }

        public Pomodoro.TimeBlock? get_last_child ()
        {
            return this.children.first ();
        }

        public void @foreach (Pomodoro.Func<Pomodoro.TimeBlock> func)
        {
            this.children.@foreach (func);
        }

        // -----------------------------------------------------------------

        // public bool is_paused (int64 timestamp = -1)
        // {
        //     if (timestamp < 0) {
        //         timestamp = Pomodoro.get_current_time ();
        //     }
        //
        //     var gap = this.gaps.first ();
        //
        //     return gap != null && gap.state == State.PAUSED && !gap.is_finished (timestamp);
        // }

        // public bool is_completed ()
        // {
        // }

        /*
        public void schedule (int64 timestamp)
        {
        }

        public void start (int64 timestamp = Pomodoro.get_current_time ())
        {
        }
        */

        // /**
        //  * Normally, you should alter `duration` to specify timeblock end.
        //  * Once
        //  */
        // public void finish (int64 timestamp = -1)  // TODO: capture context and source
        // {
        //     if (this.duration >= 0) {
        //         // already finished
        //         return;
        //     }
        //
        //     if (timestamp < 0) {
        //         timestamp = Pomodoro.get_current_time ();
        //     }
        //
        //     var gap = this.gaps.first ();
        //     if (gap != null) {
        //         gap.finish (timestamp);
        //     }
        //
        //     this.duration = int64.max (timestamp - this.timestamp, 0);
        // }

        /*
        public static TimerState? lookup (string name)
        {
            TimerState state;

            switch (name)
            {
                case "pomodoro":
                    state = new PomodoroState ();
                    break;

                case "short-break":
                    state = new ShortBreakState ();
                    break;

                case "long-break":
                    state = new LongBreakState ();
                    break;

                case "null":
                    state = new DisabledState ();
                    break;

                default:
                    state = null;
                    break;
            }

            return state;
        }
        */

        /**
         *
         */
        public signal void changed_range ();

        // public signal void finalized ();

        /*
        public void pause (int64 timestamp = -1)  // TODO: capture context
        {
            if (this.is_paused (timestamp)) {
                // already paused
                return;
            }

            this.gaps.prepend (
                new TimeBlock () {
                    timestamp = timestamp,
                    duration = -1
                }
            );

            this.changed ();
        }

        public void resume (int64 timestamp = -1)  // TODO: store source
        {
            if (!this.is_paused ()) {
                // ignore, wasn't paused
                return;
            }

            var gap = this.gaps.last ();
            gap.duration = int64.max (timestamp - gap.timestamp, 0);

            this.changed ();
        }
        */

        /*
        public double get_progress (int64 timestamp = Pomodoro.get_current_time ())
        {
            // TODO

            if (this.duration <= 0) {
                return 0.0;
            }

            return (
                ((double) timestamp) / USEC_PER_SEC - this.timestamp - offset
            ) / this.duration;
        }
        */

        // public abstract TimerState create_next_state (double score,
        //                                               double timestamp);
    }


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
            return (uint) Pomodoro.get_settings ()
                                      .get_child ("preferences")
                                      .get_double ("pomodoro-duration");
        }

        public override TimerState create_next_state (double score,
                                                      double timestamp)
        {
            var score_limit = Pomodoro.get_settings ()
                                      .get_child ("preferences")
                                      .get_double ("long-break-interval");

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
            return (uint) Pomodoro.get_settings ()
                                      .get_child ("preferences")
                                      .get_double ("short-break-duration");
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
            return (uint) Pomodoro.get_settings ()
                                      .get_child ("preferences")
                                      .get_double ("long-break-duration");
        }

        public override double calculate_progress (double score,
                                                   double timestamp)
        {
            var short_break_duration = Pomodoro.get_settings ()
                                               .get_child ("preferences")
                                               .get_double ("short-break-duration");
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
