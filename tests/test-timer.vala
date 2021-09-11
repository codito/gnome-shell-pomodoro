/*
 * This file is part of GNOME Pomodoro
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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

namespace Pomodoro
{
    public class TimerTest : Pomodoro.TestSuite
    {
        private const double POMODORO_DURATION = 25.0;
        private const double SHORT_BREAK_DURATION = 5.0;
        private const double LONG_BREAK_DURATION = 15.0;
        private const double LONG_BREAK_INTERVAL = 4.0;

        public TimerTest ()
        {
            this.add_test ("state_duration_setting",
                           this.test_state_duration_setting);

            this.add_test ("set_state",
                           this.test_set_state);

            this.add_test ("start",
                           this.test_start);

            this.add_test ("stop",
                           this.test_stop);

            this.add_test ("update",
                           this.test_update);

            this.add_test ("update_offset",
                           this.test_update_offset);

            this.add_test ("disabled_state",
                           this.test_disabled_state);

            this.add_test ("short_break_state",
                           this.test_short_break_state);

            this.add_test ("long_break_state",
                           this.test_long_break_state);

            this.add_test ("long_break_state_postponed",
                           this.test_long_break_state_postponed);

            this.add_test ("pomodoro_state_create_next_state",
                           this.test_pomodoro_state_create_next_state);

            this.add_test ("pause_1",
                           this.test_pause_1);

            this.add_test ("pause_2",
                           this.test_pause_2);

            this.add_test ("is_running",
                           this.test_is_running);

            this.add_test ("restore_1",
                           this.test_restore_1);

            this.add_test ("restore_2",
                           this.test_restore_2);

            this.add_test ("restore_3",
                           this.test_restore_3);

            this.add_test ("restore_4",
                           this.test_restore_4);

            this.add_test ("score_1",
                           this.test_score_1);

            this.add_test ("score_2",
                           this.test_score_2);

            this.add_test ("score_3",
                           this.test_score_3);

            this.add_test ("score_4",
                           this.test_score_4);

//            this.add_test ("state_duration_change",
//                           this.test_state_duration_change);

//            this.add_test ("state_changed_signal",
//                           this.test_state_changed_signal);
        }

        public override void setup ()
        {
            var settings = Pomodoro.get_settings ()
                                   .get_child ("preferences");
            settings.set_double ("pomodoro-duration", POMODORO_DURATION);
            settings.set_double ("short-break-duration", SHORT_BREAK_DURATION);
            settings.set_double ("long-break-duration", LONG_BREAK_DURATION);
            settings.set_double ("long-break-interval", LONG_BREAK_INTERVAL);
            settings.set_boolean ("pause-when-idle", false);
        }

        public override void teardown ()
        {
            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        /**
         * Unit test for Pomodoro.Timer.set_state_full() method.
         *
         * Check changing timer state.
         */
        public void test_set_state ()
        {
            var timer = new Pomodoro.Timer ();
            var timestamp = Pomodoro.get_current_time ();

            timer.state_changed.connect ((new_state, previous_state) => {
            });

            timer.state = new PomodoroState.with_timestamp (timestamp);

            timestamp += timer.state.duration;

            timer.state = new ShortBreakState.with_timestamp (timestamp);

            timestamp += timer.state.duration;

            timer.state = new PomodoroState.with_timestamp (timestamp);
        }

        public void test_start ()
        {
            var timer = new Pomodoro.Timer ();

            timer.start ();

            assert (timer.state is PomodoroState);
            assert (timer.is_running ());

            timer.pause ();
            timer.start ();

            assert (timer.state is PomodoroState);
            assert (!timer.is_paused);
            assert (timer.is_running ());
        }

        public void test_stop ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new PomodoroState ();

            timer.stop ();

            assert (timer.state is DisabledState);
            assert (!timer.is_running ());
        }

        public void test_update ()
        {
            var timer = new Pomodoro.Timer ();
            timer.start ();

            timer.update (timer.state.timestamp + 0.5);
            assert (timer.state is PomodoroState);
            assert (timer.elapsed == 0.5);
        }

        public void test_update_offset ()
        {
            var timer = new Pomodoro.Timer ();
            var initial_timestamp = timer.timestamp;

            var state1 = new PomodoroState.with_timestamp (initial_timestamp);
            state1.elapsed = 0.5;

            timer.state = state1;

            assert (timer.elapsed == 0.5);

            var state2 = new PomodoroState.with_timestamp (initial_timestamp - 2.0);
            state2.elapsed = 0.5;

            timer.state = state2;
            timer.update (initial_timestamp);

            assert (timer.elapsed == 2.5);
        }

        public void test_disabled_state ()
        {
            var timer = new Pomodoro.Timer ();
            var initial_timestamp = timer.state.timestamp;

            timer.update (initial_timestamp + 2.0);

            assert (timer.state is Pomodoro.DisabledState);
            assert (!timer.is_running ());
            assert (timer.state.duration == 0.0);
            assert (timer.state.timestamp == initial_timestamp);
        }

        /**
         * Unit test for Pomodoro.Timer.update() method.
         *
         * Check whether states change properly with time.
         */
        public void test_short_break_state ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new PomodoroState ();
            timer.score = 0.0;

            timer.update (timer.state.timestamp + timer.state.duration);
            assert (timer.state is ShortBreakState);
            assert (timer.score == 1.0);

            timer.update (timer.state.timestamp + timer.state.duration);
        }

        public void test_long_break_state ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new PomodoroState ();
            timer.score = 3.0;

            timer.update (timer.state.timestamp + timer.state.duration);
            assert (timer.state is LongBreakState);
            assert (timer.score == 4.0);

            timer.update (timer.state.timestamp + timer.state.duration);
            assert (timer.state is PomodoroState);
            assert (timer.score == 0.0);
        }

        /**
         * Timer should not reset session count if a long break hasn't completed.
         */
        public void test_long_break_state_postponed ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new PomodoroState ();
            timer.score = 3.0;

            timer.update (timer.state.timestamp + timer.state.duration);

            assert (timer.state is LongBreakState);
            assert (timer.score == 4.0);

            var state = new PomodoroState.with_timestamp (timer.state.timestamp + 1.0);
            timer.state = state;

            assert (timer.state is PomodoroState);
            assert (timer.score == 4.0);
        }

        /**
         * Extra time from pomodoro should be passed on to a break. If interruption happens
         * (a reboot for instance) we can assume that user is not straining himself/herself.
         */
        public void test_pomodoro_state_create_next_state ()
        {
            var timer = new Pomodoro.Timer ();
            timer.start ();

            timer.update (timer.state.timestamp + timer.state.duration + 2.0);

            assert (timer.state is ShortBreakState);
            assert (timer.elapsed == 2.0);

            timer.update (timer.state.timestamp + timer.state.duration + 2.0);
            assert (timer.state is PomodoroState);
            assert (timer.elapsed == 0.0);
        }

        public void test_reset ()
        {
            // TODO
        }

        public void test_pause_1 ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer.start (0.0);
            timer.pause (0.0);
            timer.resume (2.0);
            timer.update (2.0 + 1.0);

            assert (timer.elapsed == 1.0);
            assert (timer.offset == 2.0);
        }

        /**
         * Long pauses or interruptions should not affect score.
         */
        public void test_pause_2 ()
        {
            var timer1 = new Pomodoro.Timer ();
            timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer1.start (0.0);
            timer1.pause (0.0);
            timer1.resume (15.0);
            timer1.update (15.0 + 25.0);

            assert (timer1.state is Pomodoro.ShortBreakState);
            assert (timer1.score == 1.0);

            var timer2 = new Pomodoro.Timer ();
            timer2.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer2.start (0.0);
            timer2.update (20.0);
            timer2.pause (20.0);
            timer2.resume (20.0 + 15.0);
            timer2.update (20.0 + 15.0 + 5.0);

            assert (timer2.state is Pomodoro.ShortBreakState);
            assert (timer2.score == 1.0);
        }

        public void test_is_running ()
        {
            var timer = new Pomodoro.Timer ();
            timer.pause ();

            assert (!timer.is_running ());

            timer.start ();
            timer.pause ();

            assert (!timer.is_running ());
        }

        public void test_state_duration_setting ()
        {
            Pomodoro.TimerState state;

            state = new Pomodoro.DisabledState ();
            assert (state.duration == 0.0);

            state = new Pomodoro.PomodoroState ();
            assert (state.duration == POMODORO_DURATION);

            state = new Pomodoro.ShortBreakState ();
            assert (state.duration == SHORT_BREAK_DURATION);

            state = new Pomodoro.LongBreakState ();
            assert (state.duration == LONG_BREAK_DURATION);
        }

//        /** TODO
//         * Unit test for pomodoro duration.
//         *
//         * Shortening pomodoro_duration shouldn't result in immediate long_break,
//         */
//        public void test_state_duration_change ()
//        {
//            var timer = new Pomodoro.Timer ();
//            timer.start ();
//
//            /* shorten pomodoro duration */
//            timer.state.duration = POMODORO_DURATION / 10.0;
//
//            timer.update (timer.state.timestamp + timer.state.duration);
//
////            print_timer_state (timer);
//
//            assert (timer.state is Pomodoro.ShortBreakState);
//            assert (timer.session == 1.0);
//        }

        /**
         * Test 1:1 save and restore
         */
        public void test_restore_1 ()
        {
            var settings = Pomodoro.get_settings ()
                                   .get_child ("state");

            var timer1 = new Pomodoro.Timer ();
            timer1.score = 1.0;
            timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer1.state.duration = 20.0;  // custom duration
            timer1.pause (0.0);
            timer1.resume (5.0);
            timer1.update (15.0);
            timer1.pause (15.0);
            timer1.save (settings);

            assert (settings.get_string ("timer-state") == "pomodoro");
            assert (settings.get_double ("timer-state-duration") == 20.0);
            assert (settings.get_double ("timer-elapsed") == 10.0);
            assert (settings.get_double ("timer-score") == 1.0);
            assert (settings.get_boolean ("timer-paused") == true);
            assert (
                settings.get_string ("timer-state-date") == "1970-01-01T00:00:00Z" ||
                settings.get_string ("timer-state-date") == "1970-01-01T00:00:00+0000"
            );
            assert (
                settings.get_string ("timer-date") == "1970-01-01T00:00:15Z" ||
                settings.get_string ("timer-date") == "1970-01-01T00:00:15+0000"
            );

            var timer2 = new Pomodoro.Timer ();
            timer2.restore (settings, timer1.timestamp);

            assert (timer2.state.name == timer1.state.name);
            assert (timer2.state.elapsed == timer1.state.elapsed);
            assert (timer2.state.duration == timer1.state.duration);
            assert (timer2.state.timestamp == timer1.state.timestamp);
            assert (timer2.score == timer1.score);
            assert (timer2.timestamp == timer1.timestamp);
            assert (timer2.offset == timer1.offset);
            assert (timer2.is_paused == timer1.is_paused);
        }

        /**
         * Test wether we go to next state during restore or continue where we left
         */
        public void test_restore_2 ()
        {
            var settings = Pomodoro.get_settings ()
                                   .get_child ("state");

            var timer1 = new Pomodoro.Timer ();
            timer1.score = 1.0;
            timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer1.start (0.0);
            timer1.update (10.0);
            timer1.pause (10.0);
            timer1.update (15.0);
            timer1.save (settings);

            var timer2 = new Pomodoro.Timer ();
            timer2.restore (settings, 20.0);

            assert (timer2.state.name == timer1.state.name);
            assert (timer2.state.elapsed == timer1.state.elapsed);
            assert (timer2.state.duration == timer1.state.duration);
            assert (timer2.state.timestamp == timer1.state.timestamp);
            assert (timer2.score == timer1.score);
            assert (timer2.is_paused == timer1.is_paused);

            assert (timer2.timestamp == 20.0);
            assert (timer2.offset == 10.0);
        }

        /**
         * Test whether timer is reset during restore after 1h
         */
        public void test_restore_3 ()
        {
            var settings = Pomodoro.get_settings ()
                                   .get_child ("state");

            var timer1 = new Pomodoro.Timer ();
            timer1.score = 1.0;
            timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer1.start (0.0);
            timer1.update (10.0);
            timer1.pause (10.0);
            timer1.update (15.0);
            timer1.save (settings);

            var timer2 = new Pomodoro.Timer ();
            timer2.restore (settings, 20.0 + 3600.0);

            assert (timer2.state is Pomodoro.DisabledState);
            assert (timer2.state.elapsed == 0.0);
            assert (timer2.state.timestamp == 3620.0);
            assert (timer2.score == 0.0);
            assert (timer2.timestamp == 3620.0);
            assert (timer2.offset == 0.0);
            assert (timer2.is_paused == false);
        }

        /**
         * Test against bad values
         */
        public void test_restore_4 ()
        {
            var settings = Pomodoro.get_settings ()
                                   .get_child ("state");

            settings.set_string ("timer-state", "pomodoro");
            settings.set_double ("timer-state-duration", 10.0);
            settings.set_double ("timer-elapsed", 1.0);
            settings.set_double ("timer-score", 1.0);
            settings.set_boolean ("timer-paused", false);
            settings.set_string ("timer-state-date", "invalid value");
            settings.set_string ("timer-date", "invalid value");

            var timer = new Pomodoro.Timer ();
            timer.restore (settings, 3600.0);

            assert (timer.state is Pomodoro.DisabledState);
        }

        /**
         * Test whether score is counted after pomodoro
         */
        public void test_score_1 ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
            timer.update (timer.state.duration);

            assert (timer.score == 1.0);
        }

        /**
         * Test whether score is reset after a long break
         */
        public void test_score_2 ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new Pomodoro.LongBreakState.with_timestamp (0.0);
            timer.score = 4.0;
            timer.update (timer.state.duration);

            assert (timer.state is Pomodoro.PomodoroState);
            assert (timer.score == 0.0);
        }

        /**
         * Test whether score kept when stopping timer
         */
        public void test_score_3 ()
        {
            var timer = new Pomodoro.Timer ();
            timer.score = 1.0;
            timer.start ();
            timer.stop ();

            assert (timer.score == 1.0);
        }

        /**
         * Timer should reset score after 1h of inactivity.
         */
        public void test_score_4 ()
        {
            var timer = new Pomodoro.Timer ();
            timer.state = new Pomodoro.DisabledState.with_timestamp (0.0);
            timer.score = 1.0;

            timer.state_leave.connect ((old_state) => {
                message ("*** state_leave %g", old_state.timestamp);
            });
            timer.state_enter.connect ((new_state) => {
                message ("*** state_enter %g", new_state.timestamp);
            });

            timer.start (timer.state.timestamp + 3600.0);

            assert (timer.score == 0.0);
        }

    //     private static void print_timer_state (Pomodoro.Timer timer)
    //     {
    //         stdout.printf ("""
    // %s
    //     state.name = %s
    //     state.timestamp = %.2f
    //     state.duration = %.2f
    //     score = %.2f
    //     elapsed = %.2f
    //     offset = %.2f
    //     timestamp = %.2f
    // """,
    //             timer.state.get_type ().name (),
    //             timer.state.name,
    //             timer.state.timestamp,
    //             timer.state.duration,
    //             timer.score,
    //             timer.elapsed,
    //             timer.offset,
    //             timer.timestamp);
    //     }
    }
}
