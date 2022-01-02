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
            started_time = Pomodoro.Timestamp.UNDEFINED,
            stopped_time = now,
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
            started_time = timestamp,
            stopped_time = Pomodoro.Timestamp.UNDEFINED,
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
            started_time = timestamp,
            stopped_time = now,
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
            started_time = timestamp,
            stopped_time = now,
            is_finished = true,
            user_data = user_data
        };
    }

    private bool wait_timer (Pomodoro.Timer timer)
                             requires (!Pomodoro.Timestamp.is_frozen ())
    {
        var main_context = GLib.MainContext.@default ();
        var timeout = (uint) (timer.calculate_remaining () / 1000 + 2000);
        var timeout_id = (uint) 0;
        var success = true;

        timeout_id = GLib.Timeout.add (timeout, () => {
            timeout_id = 0;
            success = false;

            return GLib.Source.REMOVE;
        });

        while (success && timer.is_running ()) {
            main_context.iteration (true);
        }

        GLib.Source.remove (timeout_id);

        return success;
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
                started_time = 3,
                stopped_time = 4,
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

            // TODO: calculate_elapsed for more states
            // this.add_test ("calculate_elapsed__initial_state",
            //                this.test_calculate_elapsed__initial_state);
            this.add_test ("calculate_elapsed__started_state",
                           this.test_calculate_elapsed__started_state);
            // this.add_test ("calculate_elapsed__stopped_state",
            //                this.test_calculate_elapsed__stopped_state);
            // this.add_test ("calculate_elapsed__finished_state",
            //                this.test_calculate_elapsed__finished_state);

            // TODO
            // this.add_test ("calculate_remaining__initial_state",
            //                this.test_calculate_remaining__initial_state);
            // this.add_test ("calculate_remaining__started_state",
            //                this.test_calculate_remaining__started_state);
            // this.add_test ("calculate_remaining__stopped_state",
            //                this.test_calculate_remaining__stopped_state);
            // this.add_test ("calculate_remaining__finished_state",
            //                this.test_calculate_remaining__finished_state);

            // TODO
            // this.add_test ("calculate_progress__initial_state",
            //                this.test_calculate_progress__initial_state);
            // this.add_test ("calculate_progress__started_state",
            //                this.test_calculate_progress__started_state);
            // this.add_test ("calculate_progress__stopped_state",
            //                this.test_calculate_progress__stopped_state);
            // this.add_test ("calculate_progress__finished_state",
            //                this.test_calculate_progress__finished_state);

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

            // TODO
            // this.add_test ("finish__initial_state",
            //                this.test_finish__initial_state);
            // this.add_test ("finish__started_state",
            //                this.test_finish__started_state);
            // this.add_test ("finish__stopped_state",
            //                this.test_finish__stopped_state);
            // this.add_test ("finish__finished_state",
            //                this.test_finish__finished_state);

            this.add_test ("finished_signal__0s",
                           this.test_finished_signal__0s);
            this.add_test ("finished_signal__1s",
                           this.test_finished_signal__1s);
            this.add_test ("finished_signal__3s",
                           this.test_finished_signal__3s);

            // TODO
            // this.add_test ("synchronize_signal",
            //                this.test_synchronize_signal);
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
                    timer.calculate_elapsed (timer.state.started_time - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (timer.state.started_time + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (timer.state.started_time + timer.duration + Pomodoro.Interval.MINUTE)
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
                        timer_with_offset.state.started_time + timer_with_offset.state.offset + Pomodoro.Interval.MINUTE
                    )
                ),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer_with_offset.calculate_elapsed (
                        timer_with_offset.state.started_time + 5 * Pomodoro.Interval.MINUTE
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
                    started_time = 2,
                    stopped_time = 3,
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
            expected_state.started_time = now + 5 * Pomodoro.Interval.MINUTE;
            expected_state.stopped_time = Pomodoro.Timestamp.UNDEFINED;

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
            expected_state.stopped_time = Pomodoro.Timestamp.UNDEFINED;

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
            expected_state.stopped_time = now + 5 * Pomodoro.Interval.MINUTE;

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


        /*
         * Tests for .finish()
         */
        // TODO



        /*
         * Tests for signals
         */

        public void test_finished_signal__0s ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var timer = new Pomodoro.Timer (0);

            var finished_emitted = 0;
            timer.finished.connect (() => {
                finished_emitted++;
            });

            timer.start ();
            assert_false (timer.is_running ());
            assert_true (timer.is_finished ());
            assert_true (wait_timer (timer));
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);

            timer.start ();
            assert_false (timer.is_running ());
            assert_true (timer.is_finished ());
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_finished_signal__1s ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var timer = new Pomodoro.Timer (1 * Pomodoro.Interval.SECOND);

            var finished_emitted = 0;
            timer.finished.connect (() => {
                finished_emitted++;
            });

            timer.start ();
            assert_true (timer.is_running ());
            assert_false (timer.is_finished ());
            assert_true (wait_timer (timer));
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);

            timer.start ();
            assert_false (timer.is_running ());
            assert_true (timer.is_finished ());
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_finished_signal__3s ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var timer = new Pomodoro.Timer (3 * Pomodoro.Interval.SECOND);

            var finished_emitted = 0;
            timer.finished.connect (() => {
                finished_emitted++;
            });

            timer.start ();
            assert_true (timer.is_running ());
            assert_false (timer.is_finished ());
            assert_true (wait_timer (timer));
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);

            timer.start ();
            assert_false (timer.is_running ());
            assert_true (timer.is_finished ());
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);
        }
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
