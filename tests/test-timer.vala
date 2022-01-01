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

namespace Tests
{
    /*
     * Fixtures
     */

    private Pomodoro.TimerState create_initial_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        return Pomodoro.TimerState () {
            duration = duration,
            offset = 0,
            start_timestamp = Pomodoro.Timestamp.UNDEFINED,
            stop_timestamp = now,
            change_timestamp = now,
            is_finished = false,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_started_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 0 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            start_timestamp = timestamp,
            stop_timestamp = Pomodoro.Timestamp.UNDEFINED,
            change_timestamp = now,
            is_finished = false,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_stopped_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 0 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            start_timestamp = timestamp,
            stop_timestamp = now,
            change_timestamp = now,
            is_finished = false,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_finished_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 10 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            start_timestamp = timestamp,
            stop_timestamp = now,
            change_timestamp = now,
            is_finished = true,
            user_data = user_data
        };
    }


    public class TimerStateTest : Tests.TestSuite
    {
        public TimerStateTest ()
        {
            this.add_test ("copy",
                           this.test_copy);
        }

        public void test_copy ()
        {
            var expected_state = Pomodoro.TimerState () {
                duration = 1,
                offset = 2,
                start_timestamp = 3,
                stop_timestamp = 4,
                change_timestamp = 5,
                is_finished = true,
                user_data = GLib.MainContext.@default()
            };
            var state = expected_state.copy ();

            assert_cmpvariant (
                state.to_variant (),
                expected_state.to_variant ()
            );
        }
    }


    public class TimerTest : Tests.TestSuite
    {
        public TimerTest ()
        {
            this.add_test ("new__without_args",
                           this.test_new__without_args);
            this.add_test ("new__with_args",
                           this.test_new__with_args);
            this.add_test ("new_with__stopped_state",
                           this.test_new_with__stopped_state);
            this.add_test ("new_with__started_state",
                           this.test_new_with__started_state);

            this.add_test ("is_running",
                           this.test_is_running);
            this.add_test ("is_started",
                           this.test_is_started);
            this.add_test ("is_stopped",
                           this.test_is_stopped);
            this.add_test ("is_finished",
                           this.test_is_finished);

            this.add_test ("calculate_elapsed__started_state",
                           this.test_calculate_elapsed__started_state);
            // TODO: calculate_elapsed for more states

            this.add_test ("reset",
                           this.test_reset);

            this.add_test ("start__initial_state",
                           this.test_start__initial_state);
            this.add_test ("start__started_state",
                           this.test_start__started_state);
            this.add_test ("start__stopped_state",
                           this.test_start__stopped_state);
            this.add_test ("start__finished_state",
                           this.test_start__finished_state);

            this.add_test ("stop__initial_state",
                           this.test_stop__initial_state);
            this.add_test ("stop__started_state",
                           this.test_stop__started_state);
            this.add_test ("stop__stopped_state",
                           this.test_stop__stopped_state);
            this.add_test ("stop__finished_state",
                           this.test_stop__finished_state);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (1000 * Pomodoro.Interval.SECOND);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.unfreeze ();
        }


        /*
         * Tests for constructors
         */

        private void test_new__without_args ()
        {
            var now = Pomodoro.Timestamp.tick (0);
            var expected_state = create_initial_state (0);

            var timer = new Pomodoro.Timer ();
            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (expected_state.duration)
            );
            assert_true (timer.is_stopped ());
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());
        }

        private void test_new__with_args ()
        {
            var now = Pomodoro.Timestamp.tick (0);
            var user_data = GLib.MainContext.@default ();
            var expected_state = create_initial_state (Pomodoro.Interval.MINUTE,
                                                       user_data);

            var timer = new Pomodoro.Timer (expected_state.duration,
                                            expected_state.user_data);
            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (expected_state.duration)
            );
            assert_true (timer.user_data == expected_state.user_data);
            assert_true (timer.is_stopped ());
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());
        }

        private void test_new_with__stopped_state ()
        {
            var stopped_state = create_stopped_state ();
            var timer = new Pomodoro.Timer.with_state (stopped_state);
            assert_cmpvariant (
                timer.state.to_variant (),
                stopped_state.to_variant ()
            );
            assert_true (timer.is_stopped ());
            assert_false (timer.is_running ());
        }

        private void test_new_with__started_state ()
        {
            var started_state = create_started_state ();
            var timer = new Pomodoro.Timer.with_state (started_state);
            assert_cmpvariant (
                timer.state.to_variant (),
                started_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());
        }


        /*
         * Tests for properties
         */
        // TODO


        /*
         * Tests for .is_*() functions
         */
        public void test_is_running ()
        {
            assert_true (
                new Pomodoro.Timer.with_state (create_started_state ()).is_running ()
            );

            assert_false (
                new Pomodoro.Timer.with_state (create_initial_state ()).is_running ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_stopped_state ()).is_running ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_finished_state ()).is_running ()
            );
        }

        public void test_is_started ()
        {
            assert_true (
                new Pomodoro.Timer.with_state (create_started_state ()).is_started ()
            );
            assert_true (
                new Pomodoro.Timer.with_state (create_stopped_state ()).is_started ()
            );
            assert_true (
                new Pomodoro.Timer.with_state (create_finished_state ()).is_started ()
            );

            assert_false (
                new Pomodoro.Timer.with_state (create_initial_state ()).is_started ()
            );
        }

        public void test_is_stopped ()
        {
            assert_true (
                new Pomodoro.Timer.with_state (create_initial_state ()).is_stopped ()
            );
            assert_true (
                new Pomodoro.Timer.with_state (create_stopped_state ()).is_stopped ()
            );
            assert_true (
                new Pomodoro.Timer.with_state (create_finished_state ()).is_stopped ()
            );

            assert_false (
                new Pomodoro.Timer.with_state (create_started_state ()).is_stopped ()
            );
        }

        public void test_is_finished ()
        {
            assert_true (
                new Pomodoro.Timer.with_state (create_finished_state ()).is_finished ()
            );

            assert_false (
                new Pomodoro.Timer.with_state (create_initial_state ()).is_finished ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_started_state ()).is_finished ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_stopped_state ()).is_finished ()
            );
        }


        /*
         * Tests for .calculate_*() functions
         */

        public void test_calculate_elapsed__started_state ()
        {
            var now = Pomodoro.Timestamp.tick (0);

            var timer = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (timer.state.start_timestamp - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (timer.state.start_timestamp + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (timer.state.start_timestamp + timer.duration + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (timer.duration)
            );

            var timer_with_offset = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer_with_offset.calculate_elapsed (
                        timer_with_offset.state.start_timestamp + timer_with_offset.state.offset + Pomodoro.Interval.MINUTE
                    )
                ),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer_with_offset.calculate_elapsed (
                        timer_with_offset.state.start_timestamp + 5 * Pomodoro.Interval.MINUTE
                    )
                ),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
        }


        /*
         * Tests for .reset()
         */
        public void test_reset ()
        {
            var expected_state = create_initial_state ();

            var timer = new Pomodoro.Timer.with_state (
                Pomodoro.TimerState () {
                    duration = expected_state.duration,
                    offset = 1,
                    start_timestamp = 2,
                    stop_timestamp = 3,
                    change_timestamp = 4,
                    is_finished = true
                }
            );
            timer.reset (expected_state.duration);

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_stopped ());
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());

            // TODO: expect change signal to be emitted
        }


        /*
         * Tests for .start()
         */

        public void test_start__initial_state ()
        {
            var now = Pomodoro.Timestamp.tick (0);

            var initial_state = create_initial_state ();
            var expected_state = initial_state.copy ();
            expected_state.start_timestamp = now + 5 * Pomodoro.Interval.MINUTE;
            expected_state.stop_timestamp = Pomodoro.Timestamp.UNDEFINED;
            expected_state.change_timestamp = now + 5 * Pomodoro.Interval.MINUTE;

            var timer = new Pomodoro.Timer.with_state (initial_state);
            Pomodoro.Timestamp.tick (5 * Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());

            // TODO: expect change signal to be emitted
        }

        /**
         * Starting from already started should ignore the call.
         */
        public void test_start__started_state ()
        {
            var started_state = create_started_state ();
            var expected_state = started_state.copy ();

            var timer = new Pomodoro.Timer.with_state (started_state);
            Pomodoro.Timestamp.tick (5 * Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());

            // TODO: expect change signal not to be emitted
        }

        /**
         * Starting from stopped state should conitnue where left off.
         *
         * Scenario:
         *  - start timer
         *  - stop after 4 minutes
         *  - start after 1 minute
         *
         * Expect elapsed time still to be 4 minutes
         */
        public void test_start__stopped_state ()
        {
            var stopped_state = create_stopped_state (
                20 * Pomodoro.Interval.MINUTE,
                4 * Pomodoro.Interval.MINUTE
            );
            var expected_state = stopped_state.copy ();
            expected_state.offset += 1 * Pomodoro.Interval.MINUTE;
            expected_state.stop_timestamp = Pomodoro.Timestamp.UNDEFINED;
            expected_state.change_timestamp += 1 * Pomodoro.Interval.MINUTE;

            var timer = new Pomodoro.Timer.with_state (stopped_state);
            Pomodoro.Timestamp.tick (1 * Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed ()),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());
            assert_false (timer.is_finished ());

            // TODO: expect change signal to be emitted
        }

        /**
         * Starting from finished state should be ignored
         */
        public void test_start__finished_state ()
        {
            var finished_state = create_finished_state ();
            var expected_state = finished_state.copy ();

            var timer = new Pomodoro.Timer.with_state (finished_state);
            Pomodoro.Timestamp.tick (Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_finished ());
            assert_false (timer.is_running ());

            // TODO: expect change signal not to be emitted
        }


        /*
         * Tests for .stop()
         */

        /**
         * Stopping from initial state should be ignored
         */
        public void test_stop__initial_state ()
        {
            var initial_state = create_initial_state ();
            var expected_state = initial_state.copy ();

            var timer = new Pomodoro.Timer.with_state (initial_state);
            Pomodoro.Timestamp.tick (5 * Pomodoro.Interval.MINUTE);
            timer.stop ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_stopped ());
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());

            // TODO: expect change signal to be emitted
        }

        /**
         * Stopping a started should preserve elapsed time.
         */
        public void test_stop__started_state ()
        {
            var now = Pomodoro.Timestamp.tick (0);

            var started_state = create_started_state ();
            var expected_state = started_state.copy ();
            expected_state.stop_timestamp = now + 5 * Pomodoro.Interval.MINUTE;
            expected_state.change_timestamp = now + 5 * Pomodoro.Interval.MINUTE;

            var timer = new Pomodoro.Timer.with_state (started_state);
            Pomodoro.Timestamp.tick (5 * Pomodoro.Interval.MINUTE);
            timer.stop ();

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed ()),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_stopped ());
            assert_true (timer.is_started ());
            assert_false (timer.is_running ());

            // TODO: expect change signal not to be emitted
        }

        /**
         * Stopping a stopped state should ignore the call.
         */
        public void test_stop__stopped_state ()
        {
            var stopped_state = create_stopped_state ();
            var expected_state = stopped_state.copy ();

            var timer = new Pomodoro.Timer.with_state (stopped_state);
            Pomodoro.Timestamp.tick (1 * Pomodoro.Interval.MINUTE);
            timer.stop ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_stopped ());
            assert_false (timer.is_running ());

            // TODO: expect change signal to be emitted
        }

        /**
         * Starting from finished state should be ignored
         */
        public void test_stop__finished_state ()
        {
            var finished_state = create_finished_state ();
            var expected_state = finished_state.copy ();

            var timer = new Pomodoro.Timer.with_state (finished_state);
            Pomodoro.Timestamp.tick (Pomodoro.Interval.MINUTE);
            timer.stop ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_finished ());
            assert_false (timer.is_running ());

            // TODO: expect change signal not to be emitted
        }


        /*
         * Tests for .skip()
         */
        // TODO


        /*
         * Tests for .rewind()
         */
        // TODO


        /*
         * Tests for .extend()
         */
        // TODO

    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimerStateTest (),
        new Tests.TimerTest ()
    );
}
