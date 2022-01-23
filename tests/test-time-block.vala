namespace Tests
{
    public class TimeBlockTest : Tests.TestSuite
    {
        public TimeBlockTest ()
        {
            this.add_test ("new__undefined",
                           this.test_new__undefined);
            this.add_test ("new__pomodoro",
                           this.test_new__pomodoro);
            this.add_test ("new__short_break",
                           this.test_new__short_break);
            this.add_test ("new__long_break",
                           this.test_new__long_break);

            this.add_test ("set_session",
                           this.test_set_session);

            this.add_test ("calculate_elapsed__without_gaps",
                           this.test_calculate_elapsed__without_gaps);
            this.add_test ("calculate_elapsed__with_gaps",
                           this.test_calculate_elapsed__with_gaps);

            this.add_test ("calculate_remaining__without_gaps",
                           this.test_calculate_remaining__without_gaps);
            this.add_test ("calculate_remaining__with_gaps",
                           this.test_calculate_remaining__with_gaps);

            // this.add_test ("state", this.test_state);
            // this.add_test ("start_time", this.test_start_time);
            // this.add_test ("end_time", this.test_end_time);
            // this.add_test ("duration", this.test_duration);
            // this.add_test ("parent", this.test_parent);
            // this.add_test ("schedule", this.test_schedule);
            // this.add_test ("has_bounds", this.test_has_bounds);
            // this.add_test ("add_child", this.test_add_child);
            // this.add_test ("remove_child", this.test_remove_child);
            // this.add_test ("get_last_child", this.test_get_last_child);
            // this.add_test ("foreach_child", this.test_foreach_child);
            // this.add_test ("changed_range_signal", this.test_changed_range_signal);
        }

        public override void setup ()
        {
            // var settings = Pomodoro.get_settings ();
            // settings.set_uint ("pomodoro-duration", POMODORO_DURATION);
            // settings.set_uint ("short-break-duration", SHORT_BREAK_DURATION);
            // settings.set_uint ("long-break-duration", LONG_BREAK_DURATION);
            // settings.set_uint ("pomodoros-per-session", LONG_BREAK_INTERVAL);
            // settings.set_boolean ("pause-when-idle", false);
        }

        public override void teardown ()
        {
            // var settings = Pomodoro.get_settings ();
            // settings.revert ();
        }


        /*
         * Tests for constructors
         */

        public void test_new__undefined ()
        {
            var state = Pomodoro.State.UNDEFINED;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            // assert_true (time_block.state_duration == state.get_default_duration ());
            assert_true (time_block.start_time == Pomodoro.Timestamp.MIN);
            assert_true (time_block.end_time == Pomodoro.Timestamp.MAX);
        }

        public void test_new__pomodoro ()
        {
            var state = Pomodoro.State.POMODORO;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            // assert_true (time_block.state_duration == state.get_default_duration ());
            assert_true (time_block.start_time == Pomodoro.Timestamp.MIN);
            assert_true (time_block.end_time == Pomodoro.Timestamp.MAX);
        }

        public void test_new__short_break ()
        {
            var state = Pomodoro.State.SHORT_BREAK;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            // assert_true (time_block.state_duration == state.get_default_duration ());
            assert_true (time_block.start_time == Pomodoro.Timestamp.MIN);
            assert_true (time_block.end_time == Pomodoro.Timestamp.MAX);
        }

        public void test_new__long_break ()
        {
            var state = Pomodoro.State.LONG_BREAK;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            // assert_true (time_block.state_duration == state.get_default_duration ());
            assert_true (time_block.start_time == Pomodoro.Timestamp.MIN);
            assert_true (time_block.end_time == Pomodoro.Timestamp.MAX);
        }


        /*
         * Tests for properties
         */

        // TODO: remove, should be set at construct level
        public void test_set_session ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);

            var notify_session_emitted = 0;
            time_block.notify["session"].connect (() => {
                notify_session_emitted++;
            });

            var session_1 = new Pomodoro.Session ();
            time_block.session = session_1;
            assert_true (time_block.session == session_1);
            assert_true (notify_session_emitted == 1);

            time_block.session = session_1;
            assert_true (time_block.session == session_1);
            assert_true (notify_session_emitted == 1);  // unchanged

            var session_2 = new Pomodoro.Session ();
            time_block.session = session_2;
            assert_true (time_block.session == session_2);
            assert_true (notify_session_emitted == 2);
        }

        public void test_state ()
        {

        }

        public void test_start_time ()
        {

        }

        public void test_end_time ()
        {

        }

        public void test_duration ()
        {

        }

        public void test_parent ()
        {

        }


        /*
         * Tests for methods
         */

        // public void to_timer_state ()
        // {
        //     var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
        //     var expected_timer_state = Pomodoro.TimerState () {

        //     };

        //     assert_cmpvariant (
        //         time_block.to_timer_state ().to_variant (),
        //         expected_timer_state.to_variant ()
        //     );
        // }

        // public void test_schedule ()
        // {
        // }

        // public void test_has_bounds ()
        // {
        // }

        // public void test_has_started ()
        // {
        // }

        // public void test_has_ended ()
        // {
        // }


        public void test_calculate_elapsed__without_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            time_block.set_time_range (
                5 * Pomodoro.Interval.MINUTE,
                30 * Pomodoro.Interval.MINUTE);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.start_time)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.start_time - Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.end_time)),
                new GLib.Variant.int64 (25 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.end_time + Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (25 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (10 * Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_elapsed__with_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            time_block.set_time_range (
                5 * Pomodoro.Interval.MINUTE,
                30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap (2 * Pomodoro.Interval.MINUTE, 9 * Pomodoro.Interval.MINUTE);  // 4 minutes
            var gap_2 = new Pomodoro.Gap (15 * Pomodoro.Interval.MINUTE, 17 * Pomodoro.Interval.MINUTE);  // 2 minutes
            var gap_3 = new Pomodoro.Gap (29 * Pomodoro.Interval.MINUTE, 35 * Pomodoro.Interval.MINUTE);  // 1 minute

            time_block.add_gap (gap_1);
            time_block.add_gap (gap_2);
            time_block.add_gap (gap_3);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.start_time)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (gap_1.end_time)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.start_time - Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.end_time)),
                new GLib.Variant.int64 ((25 - 1 - 2 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (gap_3.start_time)),
                new GLib.Variant.int64 ((25 - 1 - 2 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (time_block.end_time + Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 ((25 - 1 - 2 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (gap_2.end_time)),
                new GLib.Variant.int64 ((10 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (gap_2.start_time)),
                new GLib.Variant.int64 ((10 - 4) * Pomodoro.Interval.MINUTE)
            );
        }


        public void test_calculate_remaining__without_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            time_block.set_time_range (
                5 * Pomodoro.Interval.MINUTE,
                30 * Pomodoro.Interval.MINUTE);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.start_time)),
                new GLib.Variant.int64 (25 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.start_time - Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (25 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.end_time)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.end_time + Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (10 * Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (20 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_remaining__with_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            time_block.set_time_range (
                5 * Pomodoro.Interval.MINUTE,
                30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap (2 * Pomodoro.Interval.MINUTE, 9 * Pomodoro.Interval.MINUTE);  // 4 minutes
            var gap_2 = new Pomodoro.Gap (15 * Pomodoro.Interval.MINUTE, 17 * Pomodoro.Interval.MINUTE);  // 2 minutes
            var gap_3 = new Pomodoro.Gap (29 * Pomodoro.Interval.MINUTE, 35 * Pomodoro.Interval.MINUTE);  // 1 minute

            time_block.add_gap (gap_1);
            time_block.add_gap (gap_2);
            time_block.add_gap (gap_3);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.start_time)),
                new GLib.Variant.int64 ((25 - 1 - 2 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_1.end_time)),
                new GLib.Variant.int64 ((25 - 1 - 2 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.start_time - Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 ((25 - 1 - 2 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.end_time)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_3.start_time)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (time_block.end_time + Pomodoro.Interval.MINUTE)),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_2.end_time)),
                new GLib.Variant.int64 ((13 - 1) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_2.start_time)),
                new GLib.Variant.int64 ((13 - 1) * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_get_progress ()
        {

        }

        public void test_add_child ()
        {

        }

        public void test_remove_child ()
        {

        }

        public void test_get_last_child ()
        {
        }

        public void test_foreach_child ()
        {

        }

        public void test_scheduled_signal ()
        {

        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimeBlockTest ()
    );
}
