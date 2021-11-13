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


    public abstract class TimerState : GLib.Object
    {
        public string name { get; construct set; }
        public double elapsed { get; set; default = 0.0; }
        public double duration { get; set; default = 0.0; }
        public double timestamp { get; construct set; }

        construct
        {
            this.timestamp = Pomodoro.get_current_time ();
        }

        public double calculate_progress (int64  timestamp,
                                          double offset)  // TODO: offset should be inside state, not timer
        {
            if (this.duration <= 0.0) {
                return 0.0;
            }

            return (
                ((double) timestamp) / USEC_PER_SEC - this.timestamp - offset
            ) / this.duration;
        }

        public abstract TimerState create_next_state (double score,
                                                      double timestamp);


        /**
         * Returns acumulated score, or 0.0 if taken a long break.
         */
        public virtual double calculate_score (double score,
                                               double timestamp)
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
    }

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

        public override double calculate_score (double score,
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

            this.duration = Pomodoro.get_settings ()
                                    .get_child ("preferences")
                                    .get_double ("pomodoro-duration");
        }

        public PomodoroState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
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

        public override double calculate_score (double score,
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

            this.duration = Pomodoro.get_settings ()
                                    .get_child ("preferences")
                                    .get_double ("short-break-duration");
        }

        public ShortBreakState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }
    }

    public class LongBreakState : BreakState
    {
        construct
        {
            this.name = "long-break";

            this.duration = Pomodoro.get_settings ()
                                    .get_child ("preferences")
                                    .get_double ("long-break-duration");
        }

        public LongBreakState.with_timestamp (double timestamp)
        {
            this.timestamp = timestamp;
        }

        public override double calculate_score (double score,
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
}
