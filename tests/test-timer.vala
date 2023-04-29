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
    private int64 TEST_TIME = 2000000000 * Pomodoro.Interval.SECOND;

    private uint get_timestamp_call_count ()
    {
        var call_count = Pomodoro.Timestamp.subtract (Pomodoro.Timestamp.advance (0), TEST_TIME);

        // Vala doesn't allow casting int64 to uint, so convert through string...
        return uint.parse (call_count.to_string ());
    }


    /*
     * Fixtures
     */

    private Pomodoro.TimerState create_initial_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   void* user_data = null)
    {
        return Pomodoro.TimerState () {
            duration = duration,
            offset = 0,
            started_time = Pomodoro.Timestamp.UNDEFINED,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_started_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 0 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.advance (0);

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            started_time = timestamp,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_paused_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 0 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.advance (0);

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            started_time = timestamp,
            paused_time = now,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_finished_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 10 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.advance (0);

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            started_time = timestamp,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = now,
            user_data = user_data
        };
    }

    /**
     * Wait until timer finishes
     */
    private bool run_timer (Pomodoro.Timer timer,
                            uint           timeout = 0)
                            requires (!Pomodoro.Timestamp.is_frozen ())
    {
        var timeout_id = (uint) 0;
        var cancellable = new GLib.Cancellable ();

        if (timeout == 0) {
            timeout = Pomodoro.Timestamp.to_milliseconds_uint (
                timer.calculate_remaining () + 2 * Pomodoro.Interval.SECOND);
        }

        timeout_id = GLib.Timeout.add (timeout, () => {
            timeout_id = 0;
            cancellable.cancel ();

            return GLib.Source.REMOVE;
        });

        timer.run (cancellable);

        GLib.Source.remove (timeout_id);

        return !cancellable.is_cancelled ();
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
                paused_time = 4,
                finished_time = 5,
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
            this.add_test ("new_with__paused_state",
                           this.test_new_with__paused_state);
            this.add_test ("new_with__started_state",
                           this.test_new_with__started_state);

            this.add_test ("set_default",
                           this.test_set_default);

            this.add_test ("is_running",
                           this.test_is_running);
            this.add_test ("is_started",
                           this.test_is_started);
            this.add_test ("is_paused",
                           this.test_is_paused);
            this.add_test ("is_finished",
                           this.test_is_finished);

            this.add_test ("calculate_elapsed__initial_state",
                           this.test_calculate_elapsed__initial_state);
            this.add_test ("calculate_elapsed__started_state",
                           this.test_calculate_elapsed__started_state);
            this.add_test ("calculate_elapsed__paused_state",
                           this.test_calculate_elapsed__paused_state);
            this.add_test ("calculate_elapsed__finished_state",
                           this.test_calculate_elapsed__finished_state);

            this.add_test ("calculate_remaining__initial_state",
                           this.test_calculate_remaining__initial_state);
            this.add_test ("calculate_remaining__started_state",
                           this.test_calculate_remaining__started_state);
            this.add_test ("calculate_remaining__paused_state",
                           this.test_calculate_remaining__paused_state);
            this.add_test ("calculate_remaining__finished_state",
                           this.test_calculate_remaining__finished_state);

            this.add_test ("calculate_progress__initial_state",
                           this.test_calculate_progress__initial_state);
            this.add_test ("calculate_progress__started_state",
                           this.test_calculate_progress__started_state);
            this.add_test ("calculate_progress__paused_state",
                           this.test_calculate_progress__paused_state);
            this.add_test ("calculate_progress__finished_state",
                           this.test_calculate_progress__finished_state);

            this.add_test ("state",
                           this.test_state);
            this.add_test ("duration",
                           this.test_duration);
            this.add_test ("started_time",
                           this.test_started_time);
            this.add_test ("offset",
                           this.test_offset);
            this.add_test ("user_data",
                           this.test_user_data);

            this.add_test ("reset",
                           this.test_reset);

            this.add_test ("start__initial_state",
                           this.test_start__initial_state);
            this.add_test ("start__started_state",
                           this.test_start__started_state);
            this.add_test ("start__paused_state",
                           this.test_start__paused_state);
            this.add_test ("start__finished_state",
                           this.test_start__finished_state);

            this.add_test ("pause__initial_state",
                           this.test_pause__initial_state);
            this.add_test ("pause__started_state",
                           this.test_pause__started_state);
            this.add_test ("pause__paused_state",
                           this.test_pause__paused_state);
            this.add_test ("pause__finished_state",
                           this.test_pause__finished_state);
            this.add_test ("pause__align_to_seconds",
                           this.test_pause__align_to_seconds);

            this.add_test ("resume__initial_state",
                           this.test_resume__initial_state);
            this.add_test ("resume__started_state",
                           this.test_resume__started_state);
            this.add_test ("resume__paused_state",
                           this.test_resume__paused_state);
            this.add_test ("resume__finished_state",
                           this.test_resume__finished_state);

            this.add_test ("rewind__initial_state",
                           this.test_rewind__initial_state);
            this.add_test ("rewind__started_state",
                           this.test_rewind__started_state);
            this.add_test ("rewind__paused_state",
                           this.test_rewind__paused_state);
            this.add_test ("rewind__finished_state",
                           this.test_rewind__finished_state);
            this.add_test ("rewind__align_to_seconds",
                           this.test_rewind__align_to_seconds);

            this.add_test ("resolve_state_signal",
                           this.test_resolve_state_signal);

            this.add_test ("state_changed_signal",
                           this.test_state_changed_signal);

            this.add_test ("tick_signal",
                           this.test_tick_signal);

            this.add_test ("finished_signal__0s",
                           this.test_finished_signal__0s);
            this.add_test ("finished_signal__1s",
                           this.test_finished_signal__1s);
            this.add_test ("finished_signal__3s",
                           this.test_finished_signal__3s);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (TEST_TIME, Pomodoro.Interval.MICROSECOND);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.unfreeze ();

            Pomodoro.Timer.set_default (null);
        }


        /*
         * Tests for constructors
         */

        private void test_new__without_args ()
        {
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
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());

            // Expect contructor to not fetch system time
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.get_last_state_changed_time ()),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpuint (get_timestamp_call_count (), GLib.CompareOperator.EQ, 0);
        }

        private void test_new__with_args ()
        {
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
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());
        }

        private void test_new_with__paused_state ()
        {
            var paused_state = create_paused_state ();
            var timer = new Pomodoro.Timer.with_state (paused_state);
            assert_cmpvariant (
                timer.state.to_variant (),
                paused_state.to_variant ()
            );
            assert_true (timer.is_paused ());
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
         * Tests for static methods
         */

        private void test_set_default ()
        {
            // Expect timer to be created on demand
            var default_timer = Pomodoro.Timer.get_default ();
            assert_nonnull (default_timer);

            // Check whether default timer holds a reference
            var destroyed = false;
            default_timer.weak_ref (() => {
                destroyed = true;
            });
            default_timer = null;
            assert_false (destroyed);

            Pomodoro.Timer.set_default (null);
            assert_true (destroyed);

            // Check setting a custom timer
            var custom_timer = new Pomodoro.Timer ();
            assert_false (custom_timer.is_default ());
            Pomodoro.Timer.set_default (custom_timer);
            assert_true (Pomodoro.Timer.get_default () == custom_timer);
            assert_true (custom_timer.is_default ());
        }


        /*
         * Tests for properties
         */
        private void test_state ()
        {
            var timer = new Pomodoro.Timer ();

            var notify_state_emitted = 0;
            timer.notify["state"].connect (() => {
                notify_state_emitted++;
            });

            var state_1 = create_initial_state ();
            timer.state = state_1;
            assert_true (timer.state.equals (state_1));
            assert_cmpint (notify_state_emitted, GLib.CompareOperator.EQ, 1);

            timer.state = state_1;
            assert_true (timer.state.equals (state_1));
            assert_cmpint (notify_state_emitted, GLib.CompareOperator.EQ, 1);  // unchanged

            var state_2 = create_started_state ();
            timer.state = state_2;
            assert_true (timer.state.equals (state_2));
            assert_cmpint (notify_state_emitted, GLib.CompareOperator.EQ, 2);
        }

        private void test_duration ()
        {
            var timer = new Pomodoro.Timer ();

            var notify_duration_emitted = 0;
            timer.notify["duration"].connect (() => {
                notify_duration_emitted++;
            });

            var duration_1 = Pomodoro.Interval.MINUTE;
            timer.duration = duration_1;
            assert_true (timer.duration == duration_1);
            assert_cmpint (notify_duration_emitted, GLib.CompareOperator.EQ, 1);

            timer.duration = duration_1;
            assert_true (timer.duration == duration_1);
            assert_cmpint (notify_duration_emitted, GLib.CompareOperator.EQ, 1);  // unchanged

            var duration_2 = 2 * Pomodoro.Interval.MINUTE;
            timer.duration = duration_2;
            assert_true (timer.duration == duration_2);
            assert_cmpint (notify_duration_emitted, GLib.CompareOperator.EQ, 2);
        }

        private void test_started_time ()
        {
            var timer = new Pomodoro.Timer ();

            var notify_started_time_emitted = 0;
            timer.notify["started-time"].connect (() => {
                notify_started_time_emitted++;
            });

            var state_1 = create_started_state ();
            timer.state = state_1;
            assert_cmpint (notify_started_time_emitted, GLib.CompareOperator.EQ, 1);

            var state_2 = state_1.copy();
            state_2.user_data = new GLib.Object ();
            timer.state = state_2;
            assert_cmpint (notify_started_time_emitted, GLib.CompareOperator.EQ, 1);  // unchanged

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            var state_3 = create_started_state ();
            timer.state = state_3;
            assert_cmpint (notify_started_time_emitted, GLib.CompareOperator.EQ, 2);
        }

        private void test_offset ()
        {
            var timer = new Pomodoro.Timer ();

            var notify_offset_emitted = 0;
            timer.notify["offset"].connect (() => {
                notify_offset_emitted++;
            });

            var state_1 = create_started_state ();
            state_1.offset = Pomodoro.Interval.MINUTE;
            timer.state = state_1;
            assert_cmpint (notify_offset_emitted, GLib.CompareOperator.EQ, 1);

            var state_2 = create_started_state ();
            state_2.offset = Pomodoro.Interval.MINUTE;
            timer.state = state_2;
            assert_cmpint (notify_offset_emitted, GLib.CompareOperator.EQ, 1);  // unchanged

            var state_3 = create_started_state ();
            state_3.offset = 2 * Pomodoro.Interval.MINUTE;
            timer.state = state_3;
            assert_cmpint (notify_offset_emitted, GLib.CompareOperator.EQ, 2);
        }

        private void test_user_data ()
        {
            var timer = new Pomodoro.Timer ();

            var notify_user_data_emitted = 0;
            timer.notify["user-data"].connect (() => {
                notify_user_data_emitted++;
            });

            var user_data_1 = new GLib.Object ();
            timer.user_data = user_data_1;
            assert_true (timer.user_data == user_data_1);
            assert_cmpint (notify_user_data_emitted, GLib.CompareOperator.EQ, 1);

            timer.user_data = user_data_1;
            assert_true (timer.user_data == user_data_1);
            assert_cmpint (notify_user_data_emitted, GLib.CompareOperator.EQ, 1);  // unchanged

            var user_data_2 = new GLib.Object ();
            timer.user_data = user_data_2;
            assert_true (timer.user_data == user_data_2);
            assert_cmpint (notify_user_data_emitted, GLib.CompareOperator.EQ, 2);
        }


        /*
         * Tests for .is_*() methods
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
                new Pomodoro.Timer.with_state (create_finished_state ()).is_started ()
            );

            assert_false (
                new Pomodoro.Timer.with_state (create_initial_state ()).is_started ()
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
                new Pomodoro.Timer.with_state (create_paused_state ()).is_finished ()
            );
        }


        /*
         * Tests for .calculate_elapsed()
         */

        public void test_calculate_elapsed__initial_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_initial_state (
                    20 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (0)
            );
        }

        public void test_calculate_elapsed__started_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

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

            Pomodoro.Timestamp.freeze_to (now, Pomodoro.Interval.MICROSECOND);

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

        public void test_calculate_elapsed__paused_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_paused_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE)  // estimation
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now)
                ),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_elapsed__finished_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_finished_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE)  // estimation
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now)
                ),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_elapsed (now + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
        }


        /*
         * Tests for .calculate_remaining()
         */

        public void test_calculate_remaining__initial_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_initial_state (
                    20 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (20 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (20 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_remaining__started_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (timer.state.started_time - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (20 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (timer.state.started_time + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (19 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (timer.state.started_time + timer.duration + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (0)
            );

            Pomodoro.Timestamp.freeze_to (now, Pomodoro.Interval.MICROSECOND);

            var timer_with_offset = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer_with_offset.calculate_remaining (
                        timer_with_offset.state.started_time + timer_with_offset.state.offset + Pomodoro.Interval.MINUTE
                    )
                ),
                new GLib.Variant.int64 (19 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer_with_offset.calculate_remaining (
                        timer_with_offset.state.started_time + 5 * Pomodoro.Interval.MINUTE
                    )
                ),
                new GLib.Variant.int64 (16 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_remaining__paused_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_paused_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (17 * Pomodoro.Interval.MINUTE)  // estimation
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now)
                ),
                new GLib.Variant.int64 (16 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (16 * Pomodoro.Interval.MINUTE)
            );
        }

        /**
         * Timer duration should have precedence over marking timer as finished.
         * Therefore, finished timer can still have some remaining time.
         */
        public void test_calculate_remaining__finished_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_finished_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );

            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now - Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (17 * Pomodoro.Interval.MINUTE)  // estimation
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now)
                ),
                new GLib.Variant.int64 (16 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (
                    timer.calculate_remaining (now + Pomodoro.Interval.MINUTE)
                ),
                new GLib.Variant.int64 (16 * Pomodoro.Interval.MINUTE)
            );
        }


        /*
         * Tests for .calculate_progress()
         */

        public void test_calculate_progress__initial_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_initial_state (
                    20 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpvariant (
                timer.calculate_progress (now - Pomodoro.Interval.MINUTE),
                0.0
            );
            assert_cmpvariant (
                timer.calculate_progress (now + Pomodoro.Interval.MINUTE),
                0.0
            );
        }

        public void test_calculate_progress__started_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpfloat (
                timer.calculate_progress (timer.state.started_time - Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                0.0 / 20.0
            );
            assert_cmpfloat (
                timer.calculate_progress (timer.state.started_time + Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                1.0 / 20.0
            );
            assert_cmpfloat (
                timer.calculate_progress (timer.state.started_time + timer.duration + Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                20.0 / 20.0
            );

            Pomodoro.Timestamp.freeze_to (now, Pomodoro.Interval.MICROSECOND);

            var timer_with_offset = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpfloat (
                timer_with_offset.calculate_progress (
                    timer_with_offset.state.started_time + timer_with_offset.state.offset + Pomodoro.Interval.MINUTE
                ),
                GLib.CompareOperator.EQ,
                1.0 / 20.0
            );
            assert_cmpfloat (
                timer_with_offset.calculate_progress (
                    timer_with_offset.state.started_time + 5 * Pomodoro.Interval.MINUTE
                ),
                GLib.CompareOperator.EQ,
                4.0 / 20.0
            );
        }

        public void test_calculate_progress__paused_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_paused_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );
            assert_cmpfloat (
                timer.calculate_progress (now - Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                3.0 / 20.0
            );
            assert_cmpfloat (
                timer.calculate_progress (now),
                GLib.CompareOperator.EQ,
                4.0 / 20.0
            );
            assert_cmpfloat (
                timer.calculate_progress (now + Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                4.0 / 20.0
            );
        }

        /**
         * Timer duration should have precedence over marking timer as finished.
         * Therefore, finished timer can still have some remaining time.
         */
        public void test_calculate_progress__finished_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_finished_state (
                    20 * Pomodoro.Interval.MINUTE,
                    4 * Pomodoro.Interval.MINUTE,
                    now - 5 * Pomodoro.Interval.MINUTE
                )
            );

            assert_cmpfloat (
                timer.calculate_progress (now - Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                3.0 / 20.0
            );
            assert_cmpfloat (
                timer.calculate_progress (now),
                GLib.CompareOperator.EQ,
                4.0 / 20.0
            );
            assert_cmpfloat (
                timer.calculate_progress (now + Pomodoro.Interval.MINUTE),
                GLib.CompareOperator.EQ,
                4.0 / 20.0
            );
        }


        /*
         * Tests for .reset()
         */

        public void test_reset ()
        {
            var expected_state = create_initial_state ();
            var signals = new string[0];

            var timer = new Pomodoro.Timer.with_state (
                Pomodoro.TimerState () {
                    duration = expected_state.duration,
                    offset = 1,
                    started_time = 2,
                    paused_time = 3,
                    finished_time = 4
                }
            );
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            timer.finished.connect (() => { signals += "finished"; });

            timer.reset (expected_state.duration);

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());
            assert_cmpstrv (signals, {"resolve-state", "state-changed"});
        }


        /*
         * Tests for .start()
         */

        public void test_start__initial_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var signals = new string[0];
            var state_changed_time = Pomodoro.Timestamp.UNDEFINED;

            var initial_state = create_initial_state ();
            var expected_state = initial_state.copy ();
            expected_state.started_time = now + 5 * Pomodoro.Interval.MINUTE;
            expected_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            var timer = new Pomodoro.Timer.with_state (initial_state);
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => {
                signals += "state-changed";
                state_changed_time = timer.get_last_state_changed_time ();
            });

            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.start (now);

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());
            assert_cmpstrv (signals, {"resolve-state", "state-changed"});
            assert_cmpvariant (
                new GLib.Variant.int64 (state_changed_time),
                new GLib.Variant.int64 (timer.state.started_time)
            );
        }

        /**
         * Starting from already started state.
         *
         * Expect call to be ignored.
         */
        public void test_start__started_state ()
        {
            var started_state = create_started_state ();
            var expected_state = started_state.copy ();

            var timer = new Pomodoro.Timer.with_state (started_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Starting from paused state.
         *
         * Expect call to be ignored. If you want to resume timer you should use `.resume()`.
         */
        public void test_start__paused_state ()
        {
            var paused_state = create_paused_state (
                20 * Pomodoro.Interval.MINUTE,
                4 * Pomodoro.Interval.MINUTE
            );
            var expected_state = paused_state.copy ();

            var timer = new Pomodoro.Timer.with_state (paused_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Starting from finished state.
         *
         * Expect call to be ignored.
         */
        public void test_start__finished_state ()
        {
            var finished_state = create_finished_state ();
            var expected_state = finished_state.copy ();

            var timer = new Pomodoro.Timer.with_state (finished_state);
            Pomodoro.Timestamp.advance (1 * Pomodoro.Interval.MINUTE);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }


        /*
         * Tests for .pause()
         */

        /**
         * Pausing from initial state. Expect call to be ignored.
         */
        public void test_pause__initial_state ()
        {
            var initial_state = create_initial_state ();
            var expected_state = initial_state.copy ();

            var timer = new Pomodoro.Timer.with_state (initial_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.pause ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Pausing a started should preserve elapsed time.
         */
        public void test_pause__started_state ()
        {
            var started_state = create_started_state ();
            var expected_state = started_state.copy ();
            expected_state.paused_time = expected_state.started_time + 5 * Pomodoro.Interval.MINUTE;

            var timer = new Pomodoro.Timer.with_state (started_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.freeze_to (expected_state.paused_time, Pomodoro.Interval.MICROSECOND);
            timer.pause (expected_state.paused_time);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (expected_state.paused_time)),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_paused ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Pausing a paused state should ignore the call.
         */
        public void test_pause__paused_state ()
        {
            var paused_state = create_paused_state ();
            var expected_state = paused_state.copy ();

            var timer = new Pomodoro.Timer.with_state (paused_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (1 * Pomodoro.Interval.MINUTE);
            timer.pause ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_started ());
            assert_true (timer.is_paused ());
            assert_false (timer.is_running ());
            assert_false (timer.is_finished ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Pausing from finished state. Expect call to be ignored.
         */
        public void test_pause__finished_state ()
        {
            var finished_state = create_finished_state ();
            var expected_state = finished_state.copy ();

            var timer = new Pomodoro.Timer.with_state (finished_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (1 * Pomodoro.Interval.MINUTE);
            timer.pause ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * After resumimg timer we want to wait roughly 1s for the next tick.
         * This implies that elapsed time should be rounded.
         */
        public void test_pause__align_to_seconds ()
        {
            var started_state = create_started_state ();
            var timer = new Pomodoro.Timer.with_state (started_state);
            var pause_time = timer.state.started_time + 3200 * Pomodoro.Interval.MILLISECOND;

            Pomodoro.Timestamp.freeze_to (pause_time, Pomodoro.Interval.MICROSECOND);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (pause_time)),
                new GLib.Variant.int64 (3200 * Pomodoro.Interval.MILLISECOND)
            );

            timer.pause (pause_time);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (pause_time)),
                new GLib.Variant.int64 (3 * Pomodoro.Interval.SECOND)
            );
        }

        /*
         * Tests for .resume()
         */

        /**
         * Resuming from initial state. Expect call to be ignored.
         */
        public void test_resume__initial_state ()
        {
            var initial_state = create_initial_state ();
            var expected_state = initial_state.copy ();

            var timer = new Pomodoro.Timer.with_state (initial_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.resume ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Resuming from started state. Expect call to be ignored.
         */
        public void test_resume__started_state ()
        {
            var started_state = create_started_state ();
            var expected_state = started_state.copy ();

            var timer = new Pomodoro.Timer.with_state (started_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.resume ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Resuming a paused state.
         */
        public void test_resume__paused_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var paused_state = create_paused_state ();
            var expected_state = paused_state.copy ();
            expected_state.offset += 1 * Pomodoro.Interval.MINUTE;
            expected_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            var timer = new Pomodoro.Timer.with_state (paused_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            now += 1 * Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now, Pomodoro.Interval.MICROSECOND);

            timer.resume ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (timer.is_running ());
            assert_true (timer.is_started ());
            assert_false (timer.is_paused ());
            assert_false (timer.is_finished ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Resuming from finished state. Expect call to be ignored.
         */
        public void test_resume__finished_state ()
        {
            var finished_state = create_finished_state ();
            var expected_state = finished_state.copy ();

            var timer = new Pomodoro.Timer.with_state (finished_state);

            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (1 * Pomodoro.Interval.MINUTE);
            timer.resume ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }


        /*
         * Tests for .rewind()
         */

        /**
         * Rewinding an initial state. Expect call to be ignored.
         */
        public void test_rewind__initial_state ()
        {
            var initial_state = create_initial_state ();
            var expected_state = initial_state.copy ();

            var timer = new Pomodoro.Timer.with_state (initial_state);
            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.rewind (Pomodoro.Interval.MINUTE);

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_false (timer.is_running ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        /**
         * Rewinding the timer expect to only alter the offset,
         * not the started_time.
         */
        public void test_rewind__started_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_started_state (
                    20 * Pomodoro.Interval.MINUTE,
                    5 * Pomodoro.Interval.MINUTE,
                    now - 7 * Pomodoro.Interval.MINUTE
                )
            );
            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });
            var expected_started_time = timer.state.started_time;

            // Rewind 1 minute
            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (expected_started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_true (timer.is_running ());
            assert_false (timer.is_paused ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);

            // Rewind 5 minutes
            timer.rewind (5 * Pomodoro.Interval.MINUTE, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (expected_started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );
            assert_true (timer.is_running ());
            assert_false (timer.is_paused ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 2);
        }

        /**
         * Rewind a paused timer.
         *
         * There is no one obvious way to perform a `rewind` here.
         * Our take is to resume the timer and only alter `state.offset`.
         */
        public void test_rewind__paused_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_paused_state (
                    20 * Pomodoro.Interval.MINUTE,
                    5 * Pomodoro.Interval.MINUTE,
                    now - 7 * Pomodoro.Interval.MINUTE
                )
            );
            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });
            var expected_started_time = timer.state.started_time;

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed ()),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );

            // Rewind 1 minute
            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (expected_started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_true (timer.is_running ());
            assert_false (timer.is_paused ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);

            // Rewind 5 minutes
            timer.rewind (5 * Pomodoro.Interval.MINUTE, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (expected_started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );
            assert_true (timer.is_running ());
            assert_false (timer.is_paused ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 2);
        }

        public void test_rewind__finished_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);

            var timer = new Pomodoro.Timer.with_state (
                create_finished_state (
                    20 * Pomodoro.Interval.MINUTE,
                    5 * Pomodoro.Interval.MINUTE,
                    now - 7 * Pomodoro.Interval.MINUTE
                )
            );
            var state_changed_emitted = 0;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
            });
            var expected_started_time = timer.state.started_time;

            // Rewind 1 minute
            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (expected_started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_true (timer.is_running ());
            assert_false (timer.is_paused ());
            assert_false (timer.is_finished ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);

            // Rewind 5 minutes
            timer.rewind (5 * Pomodoro.Interval.MINUTE, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (expected_started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );
            assert_true (timer.is_running ());
            assert_false (timer.is_paused ());
            assert_false (timer.is_finished ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 2);
        }

        /**
         * After rewinding timer we want to wait roughly 1s for the next tick.
         * This implies that elapsed time should be rounded.
         */
        public void test_rewind__align_to_seconds ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var timer = new Pomodoro.Timer.with_state (
                create_started_state (
                    Pomodoro.Interval.MINUTE,
                    3200 * Pomodoro.Interval.MILLISECOND
                )
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (3200 * Pomodoro.Interval.MILLISECOND)
            );

            // Rewind 1s
            timer.rewind (Pomodoro.Interval.SECOND, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (2 * Pomodoro.Interval.SECOND)
            );
        }


        /*
         * Tests for signals
         */

        public void test_state_changed_signal ()
        {
            var timer = new Pomodoro.Timer (1 * Pomodoro.Interval.MINUTE);

            var state_changed_emitted = 0;
            var state_changed_time = Pomodoro.Timestamp.UNDEFINED;
            timer.state_changed.connect ((current_state, previous_state) => {
                state_changed_emitted++;
                state_changed_time = timer.get_last_state_changed_time ();
            });

            timer.start ();

            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.get_last_state_changed_time ()),
                new GLib.Variant.int64 (timer.state.started_time)
            );
        }

        /**
         * Check behavior of changing the state during resolve_state emission.
         *
         * Expect new resolve-state signal to be emitted and one state-changed signal at the end.
         */
        public void test_resolve_state_signal ()
        {
            var paused_state          = create_paused_state ();
            var resolve_state_emitted = 0;

            var timer = new Pomodoro.Timer.with_state (create_initial_state ());
            timer.resolve_state.connect ((ref state) => {
                resolve_state_emitted++;

                if (resolve_state_emitted >= 100) {
                    return;
                }

                if (state.started_time >= 0 && state.paused_time < 0) {
                    timer.state = paused_state;
                }
            });

            // Expect started state to be resolved into paused state
            timer.start ();

            // Ensure there is no infinite recursion
            assert_cmpint (resolve_state_emitted, GLib.CompareOperator.LT, 100);
            assert_cmpvariant (
                timer.state.to_variant (),
                paused_state.to_variant ()
            );
        }

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
            assert_true (run_timer (timer));
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
            assert_true (run_timer (timer));
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
            assert_true (run_timer (timer));
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);

            timer.start ();
            assert_false (timer.is_running ());
            assert_true (timer.is_finished ());
            assert_cmpint (finished_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_tick_signal ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var timer               = new Pomodoro.Timer (3 * Pomodoro.Interval.SECOND);
            var now                 = Pomodoro.Timestamp.from_now ();
            var reference_timestamp = now;

            var call_count          = 0;
            var expected_timestamp  = reference_timestamp;
            var max_deviation       = (int64) 0;

            timer.tick.connect ((_timestamp) => {
                var current_time = timer.get_current_time ();

                expected_timestamp += Pomodoro.Interval.SECOND;
                max_deviation = int64.max (max_deviation,
                                           (current_time - expected_timestamp).abs ());
                call_count++;
            });
            timer.start (reference_timestamp);
            assert_true (run_timer (timer));

            assert_cmpint (call_count, GLib.CompareOperator.GE, 2);
            assert_cmpint (call_count, GLib.CompareOperator.LE, 3);
            assert_cmpuint (Pomodoro.Timestamp.to_milliseconds_uint (max_deviation), GLib.CompareOperator.LT, 100);
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
