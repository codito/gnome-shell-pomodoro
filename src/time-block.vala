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


    /**
     * Pomodoro.TimeBlock
     *
     * Class describes an intended block of time - its type, start and end. It's synonymous with timer state
     * as blocks can be paused/resumed. Paused time we call as a "gap time".
     */
    public class TimeBlock : GLib.Object  // TODO: do we need GObject here?
    {
        public Pomodoro.State state {
            get {
                return this._state;
            }
        }

        public Pomodoro.Source source {  // TODO: store context, not just source
            get {
                return this._source;
            }
        }

        public int64 timestamp {  // TODO: rename to start
            get {
                return this._timestamp;
            }
            set {
                this._timestamp = value;
            }
        }

        public int64 duration {
            get {
                return this._duration;
            }
            set {
                this._duration = value;
            }
        }

        public int64 duration {
            get {
                if (this.end < 0) {

                }
            }
        }

        // Gaps should be defined as a child of a state, with first item as most recent.
        // A gap should not extend the time of parent block, it will be capped if it does.
        private GLib.SList<Pomodoro.TimeBlock> gaps;

        private Pomodoro.State  _state = State.UNDEFINED;
        private Pomodoro.Source _source = Source.OTHER;
        private int64           _timestamp = 0;
        private int64           _duration = -1;

        public TimeBlock (Pomodoro.State state = State.UNDEFINED,
                          // Pomodoro.State source = Source.UNDEFINED,
                          int64          timestamp = -1,
                          int64          duration = -1)
        {
            if (timestamp < 0) {
                timestamp = Pomodoro.get_current_time ();
            }

            this._state = state;
            // this._source = source;
            this._timestamp = timestamp;
            this._duration = duration;
            this.gaps = null;
        }

        // construct
        // {
        //     if (this._timestamp == 0) {
        //         this._timestamp = Pomodoro.get_current_time ();
        //     }
        // }

        public bool is_finished (int64 timestamp = -1
        {
            if (this.duration < 0) {
                return false;
            }

            if (timestamp < 0) {
                timestamp = Pomodoro.get_current_time ();
            }

            return timestamp - (this.timestamp + this.duration);
        }

        public bool is_paused (int64 timestamp = -1)
        {
            if (timestamp < 0) {
                timestamp = Pomodoro.get_current_time ();
            }

            var gap = this.gaps.first ();

            return gap != null && gap.state == State.PAUSED && !gap.is_finished (timestamp);
        }

        // public bool is_completed ()
        // {
        // }

        // public bool is_scheduled ()
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

        /**
         * Normally, you should alter `duration` to specify timeblock end.
         * Once
         */
        public void finish (int64 timestamp = -1)  // TODO: capture context and source
        {
            if (this.duration >= 0) {
                // already finished
                return;
            }

            if (timestamp < 0) {
                timestamp = Pomodoro.get_current_time ();
            }

            var gap = this.gaps.first ();
            if (gap != null) {
                gap.finish (timestamp);
            }

            this.duration = int64.max (timestamp - this.timestamp, 0);
        }

        public void add_child (Pomodoro.TimeBlock child)
        {
            // TODO: insert sorted
        }

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


        /* TODO: why these methods are virtual? */

        /**
         * Returns acumulated score, or 0.0 if taken a long break.
         */

        public int64 calculate_elapsed (int64 timestamp = -1)
        {
            // TODO: this

            return this.;
        }

        public int64 calculate_remaining (int64 timestamp = -1)
        {
            return this.;
        }

        public double calculate_progress (int64 timestamp = -1)
        {
            return score;
        }

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

        public bool is_completed ()
        {
            return this.elapsed >= this.duration;
        }

        /**
         *
         */
        public signal void changed ();
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
