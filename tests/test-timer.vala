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
            pause_timestamp = Pomodoro.Timestamp.UNDEFINED,
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
            pause_timestamp = Pomodoro.Timestamp.UNDEFINED,
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
            pause_timestamp = Pomodoro.Timestamp.UNDEFINED,
            change_timestamp = now,
            is_finished = false,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_paused_state (
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
            pause_timestamp = now,
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
            pause_timestamp = Pomodoro.Timestamp.UNDEFINED,
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
                pause_timestamp = 5,
                change_timestamp = 6,
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
            this.add_test ("is_paused",
                           this.test_is_paused);
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
            this.add_test ("start__paused_state",
                           this.test_start__paused_state);
            this.add_test ("start__finished_state",
                           this.test_start__finished_state);

            this.add_test ("stop__initial_state",
                           this.test_stop__initial_state);
            this.add_test ("stop__started_state",
                           this.test_stop__started_state);
            this.add_test ("stop__stopped_state",
                           this.test_stop__stopped_state);
            this.add_test ("stop__paused_state",
                           this.test_stop__paused_state);
            this.add_test ("stop__finished_state",
                           this.test_stop__finished_state);

            // this.add_test ("state_duration_setting",
            //                this.test_state_duration_setting);

            // this.add_test ("set_state",
            //                this.test_set_state);

            // this.add_test ("update",
            //                this.test_update);

            // this.add_test ("update_offset",
            //                this.test_update_offset);

            // this.add_test ("disabled_state",
            //                this.test_disabled_state);

            // this.add_test ("short_break_state",
            //                this.test_short_break_state);

            // this.add_test ("long_break_state",
            //                this.test_long_break_state);

            // this.add_test ("long_break_state_postponed",
            //                this.test_long_break_state_postponed);

            // this.add_test ("pomodoro_state_create_next_state",
            //                this.test_pomodoro_state_create_next_state);

            // this.add_test ("pause_1",
            //                this.test_pause_1);

            // this.add_test ("pause_2",
            //                this.test_pause_2);

            // this.add_test ("is_running",
            //                this.test_is_running);

            // this.add_test ("restore_1",
            //                this.test_restore_1);

            // this.add_test ("restore_2",
            //                this.test_restore_2);

            // this.add_test ("restore_3",
            //                this.test_restore_3);

            // this.add_test ("restore_4",
            //                this.test_restore_4);

            // this.add_test ("score_1",
            //                this.test_score_1);

            // this.add_test ("score_2",
            //                this.test_score_2);

            // this.add_test ("score_3",
            //                this.test_score_3);

            // this.add_test ("score_4",
            //                this.test_score_4);

//            this.add_test ("state_duration_change",
//                           this.test_state_duration_change);

//            this.add_test ("state_changed_signal",
//                           this.test_state_changed_signal);
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
            assert_false (timer.is_paused ());
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
            assert_false (timer.is_paused ());
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
                new Pomodoro.Timer.with_state (create_paused_state ()).is_running ()
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
                new Pomodoro.Timer.with_state (create_paused_state ()).is_started ()
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
            assert_false (
                new Pomodoro.Timer.with_state (create_paused_state ()).is_stopped ()
            );
        }

        public void test_is_paused ()
        {
            assert_true (
                new Pomodoro.Timer.with_state (create_paused_state ()).is_paused ()
            );

            assert_false (
                new Pomodoro.Timer.with_state (create_initial_state ()).is_paused ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_started_state ()).is_paused ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_stopped_state ()).is_paused ()
            );
            assert_false (
                new Pomodoro.Timer.with_state (create_finished_state ()).is_paused ()
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
            assert_false (
                new Pomodoro.Timer.with_state (create_paused_state ()).is_finished ()
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
                    pause_timestamp = 4,
                    change_timestamp = 5,
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
         * Starting from paused state should work same as resume.
         *
         * Scenario:
         *  - start timer
         *  - pause after 4 minutes
         *  - start after 1 minute
         *
         * Expect elapsed time still to be 4 minutes
         */
        public void test_start__paused_state ()
        {
            var paused_state = create_paused_state (
                20 * Pomodoro.Interval.MINUTE,
                4 * Pomodoro.Interval.MINUTE
            );
            var expected_state = paused_state.copy ();
            expected_state.offset += Pomodoro.Interval.MINUTE;
            expected_state.stop_timestamp = Pomodoro.Timestamp.UNDEFINED;
            expected_state.pause_timestamp = Pomodoro.Timestamp.UNDEFINED;
            expected_state.change_timestamp += Pomodoro.Interval.MINUTE;

            var timer = new Pomodoro.Timer.with_state (paused_state);
            Pomodoro.Timestamp.tick (Pomodoro.Interval.MINUTE);
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
            assert_false (timer.is_paused ());

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
         * Stopping from paused state should preserve elapsed time.
         *
         * Scenario:
         *  - start timer
         *  - pause after 4 minutes
         *  - stop after 1 minute
         *
         * Expect elapsed time still to be 4 minutes
         */
        public void test_stop__paused_state ()
        {
            var now = Pomodoro.Timestamp.tick (0);

            var paused_state = create_paused_state (
                20 * Pomodoro.Interval.MINUTE,
                4 * Pomodoro.Interval.MINUTE
            );
            assert (paused_state.offset == 0);

            var expected_state = paused_state.copy ();
            expected_state.offset = Pomodoro.Interval.MINUTE;
            expected_state.stop_timestamp = now + Pomodoro.Interval.MINUTE;
            expected_state.pause_timestamp = Pomodoro.Timestamp.UNDEFINED;
            expected_state.change_timestamp = now + Pomodoro.Interval.MINUTE;

            var timer = new Pomodoro.Timer.with_state (paused_state);
            Pomodoro.Timestamp.tick (Pomodoro.Interval.MINUTE);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed ()),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );

            timer.stop ();

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed ()),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_stopped ());
            assert_false (timer.is_running ());
            assert_false (timer.is_paused ());

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
         * Tests for .pause()
         */
        // TODO


        /*
         * Tests for .resume()
         */
        // TODO


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






















        // public void test_stop ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.set_state (Pomodoro.State.SHORT_BREAK);

        //     timer.stop ();

        //     assert_true (timer.is_stopped ());
        //     assert_true (!timer.is_running ());
        // }

        // public void test_update ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.start ();

        //     timer.update (timer.state.timestamp + 0.5);
        //     assert_true (timer.state is PomodoroState);
        //     assert_true (timer.elapsed == 0.5);
        // }

        // public void test_update_offset ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var initial_timestamp = timer.timestamp;

        //     var state1 = new PomodoroState.with_timestamp (initial_timestamp);
        //     state1.elapsed = 0.5;

        //     timer.state = state1;

        //     assert_true (timer.elapsed == 0.5);

        //     var state2 = new PomodoroState.with_timestamp (initial_timestamp - 2.0);
        //     state2.elapsed = 0.5;

        //     timer.state = state2;
        //     timer.update (initial_timestamp);

        //     assert_true (timer.elapsed == 2.5);
        // }

        // public void test_disabled_state ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var initial_timestamp = timer.state.timestamp;

        //     timer.update (initial_timestamp + 2.0);

        //     assert_true (timer.is_stopped ());
        //     assert_true (!timer.is_running ());
        //     assert_true (timer.state.duration == 0.0);
        //     assert_true (timer.state.timestamp == initial_timestamp);
        // }

        // /**
        //  * Unit test for Pomodoro.Timer.update() method.
        //  *
        //  * Check whether states change properly with time.
        //  */
        // public void test_short_break_state ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new PomodoroState ();
        //     timer.score = 0.0;

        //     timer.update (timer.state.timestamp + timer.state.duration);
        //     assert_true (timer.state is ShortBreakState);
        //     assert_true (timer.score == 1.0);

        //     timer.update (timer.state.timestamp + timer.state.duration);
        // }

        // public void test_long_break_state ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new PomodoroState ();
        //     timer.score = 3.0;

        //     timer.update (timer.state.timestamp + timer.state.duration);
        //     assert_true (timer.state is LongBreakState);
        //     assert_true (timer.score == 4.0);

        //     timer.update (timer.state.timestamp + timer.state.duration);
        //     assert_true (timer.state is PomodoroState);
        //     assert_true (timer.score == 0.0);
        // }

        // /**
        //  * Timer should not reset session count if a long break hasn't completed.
        //  */
        // public void test_long_break_state_postponed ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new PomodoroState ();
        //     timer.score = 3.0;

        //     timer.update (timer.state.timestamp + timer.state.duration);

        //     assert_true (timer.state is LongBreakState);
        //     assert_true (timer.score == 4.0);

        //     var state = new PomodoroState.with_timestamp (timer.state.timestamp + 1.0);
        //     timer.state = state;

        //     assert_true (timer.state is PomodoroState);
        //     assert_true (timer.score == 4.0);
        // }

        // /**
        //  * Extra time from pomodoro should be passed on to a break. If interruption happens
        //  * (a reboot for instance) we can assume that user is not straining himself/herself.
        //  */
        // public void test_pomodoro_state_create_next_state ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.start ();

        //     timer.update (timer.state.timestamp + timer.state.duration + 2.0);

        //     assert_true (timer.state is ShortBreakState);
        //     assert_true (timer.elapsed == 2.0);

        //     timer.update (timer.state.timestamp + timer.state.duration + 2.0);
        //     assert_true (timer.state is PomodoroState);
        //     assert_true (timer.elapsed == 0.0);
        // }

        // public void test_reset ()
        // {
            // TODO
        // }

        // public void test_pause_1 ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer.start (0.0);
        //     timer.pause (0.0);
        //     timer.resume (2.0);
        //     timer.update (2.0 + 1.0);

        //     assert_true (timer.elapsed == 1.0);
        //     assert_true (timer.offset == 2.0);
        // }

        // /**
        //  * Long pauses or interruptions should not affect score.
        //  */
        // public void test_pause_2 ()
        // {
        //     var timer1 = new Pomodoro.Timer ();
        //     timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer1.start (0.0);
        //     timer1.pause (0.0);
        //     timer1.resume (15.0);
        //     timer1.update (15.0 + 25.0);

        //     assert_true (timer1.state is Pomodoro.ShortBreakState);
        //     assert_true (timer1.score == 1.0);

        //     var timer2 = new Pomodoro.Timer ();
        //     timer2.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer2.start (0.0);
        //     timer2.update (20.0);
        //     timer2.pause (20.0);
        //     timer2.resume (20.0 + 15.0);
        //     timer2.update (20.0 + 15.0 + 5.0);

        //     assert_true (timer2.state is Pomodoro.ShortBreakState);
        //     assert_true (timer2.score == 1.0);
        // }

        // public void test_is_running ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.pause ();

        //     assert_true (!timer.is_running ());

        //     timer.start ();
        //     timer.pause ();

        //     assert_true (!timer.is_running ());
        // }

        // public void test_state_duration_setting ()
        // {
        //     Pomodoro.TimerState state;

        //     state = new Pomodoro.DisabledState ();
        //     assert_true (state.duration == 0.0);

        //     state = new Pomodoro.PomodoroState ();
        //     assert_true (state.duration == POMODORO_DURATION);

        //     state = new Pomodoro.ShortBreakState ();
        //     assert_true (state.duration == SHORT_BREAK_DURATION);

        //     state = new Pomodoro.LongBreakState ();
        //     assert_true (state.duration == LONG_BREAK_DURATION);
        // }

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
//            assert_true (timer.state is Pomodoro.ShortBreakState);
//            assert_true (timer.session == 1.0);
//        }

        // /**
        //  * Test 1:1 save and restore
        //  */
        // public void test_restore_1 ()
        // {
        //     var settings = Pomodoro.get_settings ()
        //                            .get_child ("state");

        //     var timer1 = new Pomodoro.Timer ();
        //     timer1.score = 1.0;
        //     timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer1.state.duration = 20.0;  // custom duration
        //     timer1.pause (0.0);
        //     timer1.resume (5.0);
        //     timer1.update (15.0);
        //     timer1.pause (15.0);
        //     timer1.save (settings);

        //     assert_true (settings.get_string ("timer-state") == "pomodoro");
        //     assert_true (settings.get_double ("timer-state-duration") == 20.0);
        //     assert_true (settings.get_double ("timer-elapsed") == 10.0);
        //     assert_true (settings.get_double ("timer-score") == 1.0);
        //     assert_true (settings.get_boolean ("timer-paused") == true);
        //     assert_true (
        //         settings.get_string ("timer-state-date") == "1970-01-01T00:00:00Z" ||
        //         settings.get_string ("timer-state-date") == "1970-01-01T00:00:00+0000"
        //     );
        //     assert_true (
        //         settings.get_string ("timer-date") == "1970-01-01T00:00:15Z" ||
        //         settings.get_string ("timer-date") == "1970-01-01T00:00:15+0000"
        //     );

        //     var timer2 = new Pomodoro.Timer ();
        //     timer2.restore (settings, timer1.timestamp);

        //     assert_true (timer2.state.name == timer1.state.name);
        //     assert_true (timer2.state.elapsed == timer1.state.elapsed);
        //     assert_true (timer2.state.duration == timer1.state.duration);
        //     assert_true (timer2.state.timestamp == timer1.state.timestamp);
        //     assert_true (timer2.score == timer1.score);
        //     assert_true (timer2.timestamp == timer1.timestamp);
        //     assert_true (timer2.offset == timer1.offset);
        //     assert_true (timer2.is_paused == timer1.is_paused);
        // }

        // /**
        //  * Test wether we go to next state during restore or continue where we left
        //  */
        // public void test_restore_2 ()
        // {
        //     var settings = Pomodoro.get_settings ()
        //                            .get_child ("state");

        //     var timer1 = new Pomodoro.Timer ();
        //     timer1.score = 1.0;
        //     timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer1.start (0.0);
        //     timer1.update (10.0);
        //     timer1.pause (10.0);
        //     timer1.update (15.0);
        //     timer1.save (settings);

        //     var timer2 = new Pomodoro.Timer ();
        //     timer2.restore (settings, 20.0);

        //     assert_true (timer2.state.name == timer1.state.name);
        //     assert_true (timer2.state.elapsed == timer1.state.elapsed);
        //     assert_true (timer2.state.duration == timer1.state.duration);
        //     assert_true (timer2.state.timestamp == timer1.state.timestamp);
        //     assert_true (timer2.score == timer1.score);
        //     assert_true (timer2.is_paused == timer1.is_paused);

        //     assert_true (timer2.timestamp == 20.0);
        //     assert_true (timer2.offset == 10.0);
        // }

        // /**
        //  * Test whether timer is reset during restore after 1h
        //  */
        // public void test_restore_3 ()
        // {
        //     var settings = Pomodoro.get_settings ()
        //                            .get_child ("state");

        //     var timer1 = new Pomodoro.Timer ();
        //     timer1.score = 1.0;
        //     timer1.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer1.start (0.0);
        //     timer1.update (10.0);
        //     timer1.pause (10.0);
        //     timer1.update (15.0);
        //     timer1.save (settings);

        //     var timer2 = new Pomodoro.Timer ();
        //     timer2.restore (settings, 20.0 + 3600.0);

        //     assert_true (timer2.is_stopped ());
        //     assert_true (timer2.state.elapsed == 0.0);
        //     assert_true (timer2.state.timestamp == 3620.0);
        //     assert_true (timer2.score == 0.0);
        //     assert_true (timer2.timestamp == 3620.0);
        //     assert_true (timer2.offset == 0.0);
        //     assert_true (timer2.is_paused == false);
        // }

        // /**
        //  * Test against bad values
        //  */
        // public void test_restore_4 ()
        // {
        //     var settings = Pomodoro.get_settings ()
        //                            .get_child ("state");

        //     settings.set_string ("timer-state", "pomodoro");
        //     settings.set_double ("timer-state-duration", 10.0);
        //     settings.set_double ("timer-elapsed", 1.0);
        //     settings.set_double ("timer-score", 1.0);
        //     settings.set_boolean ("timer-paused", false);
        //     settings.set_string ("timer-state-date", "invalid value");
        //     settings.set_string ("timer-date", "invalid value");

        //     var timer = new Pomodoro.Timer ();
        //     timer.restore (settings, 3600.0);

        //     assert_true (timer.is_stopped ());
        // }

        // /**
        //  * Test whether score is counted after pomodoro
        //  */
        // public void test_score_1 ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new Pomodoro.PomodoroState.with_timestamp (0.0);
        //     timer.update (timer.state.duration);

        //     assert_true (timer.score == 1.0);
        // }

        // /**
        //  * Test whether score is reset after a long break
        //  */
        // public void test_score_2 ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new Pomodoro.LongBreakState.with_timestamp (0.0);
        //     timer.score = 4.0;
        //     timer.update (timer.state.duration);

        //     assert_true (timer.state is Pomodoro.PomodoroState);
        //     assert_true (timer.score == 0.0);
        // }

        // /**
        //  * Test whether score kept when stopping timer
        //  */
        // public void test_score_3 ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.score = 1.0;
        //     timer.start ();
        //     timer.stop ();

        //     assert_true (timer.score == 1.0);
        // }

        // /**
        //  * Timer should reset score after 1h of inactivity.
        //  */
        // public void test_score_4 ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     timer.state = new Pomodoro.DisabledState.with_timestamp (0.0);
        //     timer.score = 1.0;

        //     timer.state_leave.connect ((old_state) => {
        //         message ("*** state_leave %g", old_state.timestamp);
        //     });
        //     timer.state_enter.connect ((new_state) => {
        //         message ("*** state_enter %g", new_state.timestamp);
        //     });

        //     timer.start (timer.state.timestamp + 3600.0);

        //     assert_true (timer.score == 0.0);
        // }

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


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimerStateTest (),
        new Tests.TimerTest ()
    );
}
