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

            this.add_test ("move_by__without_gaps", this.test_move_by__without_gaps);
            this.add_test ("move_by__with_gaps", this.test_move_by__with_gaps);
            this.add_test ("move_to", this.test_move_to);
            this.add_test ("add_gap", this.test_add_gap);
            this.add_test ("remove_gap", this.test_remove_gap);

            this.add_test ("calculate_elapsed__without_gaps",
                           this.test_calculate_elapsed__without_gaps);
            this.add_test ("calculate_elapsed__with_gaps",
                           this.test_calculate_elapsed__with_gaps);
            this.add_test ("calculate_elapsed__with_gaps_overlapping",
                           this.test_calculate_elapsed__with_gaps_overlapping);

            this.add_test ("calculate_remaining__without_gaps",
                           this.test_calculate_remaining__without_gaps);
            this.add_test ("calculate_remaining__with_gaps",
                           this.test_calculate_remaining__with_gaps);
            this.add_test ("calculate_remaining__with_gaps_overlapping",
                           this.test_calculate_remaining__with_gaps_overlapping);

            this.add_test ("calculate_progress__without_gaps",
                           this.test_calculate_progress__without_gaps);
            this.add_test ("calculate_progress__with_gaps",
                           this.test_calculate_progress__with_gaps);
            this.add_test ("calculate_progress__with_ongoing_gap",
                           this.test_calculate_progress__with_ongoing_gap);
            this.add_test ("calculate_progress__with_gaps_overlapping",
                           this.test_calculate_progress__with_gaps_overlapping);

            // this.add_test ("calculate_progress_inv__without_gaps",
            //                this.test_calculate_progress_inv__without_gaps);
            // this.add_test ("calculate_progress_inv__with_gaps",
            //                this.test_calculate_progress_inv__with_gaps);
            // this.add_test ("calculate_progress_inv__with_gaps_overlapping",
            //                this.test_calculate_progress_inv__with_gaps_overlapping);

            // this.add_test ("state", this.test_state);
            // this.add_test ("start_time", this.test_start_time);
            // this.add_test ("end_time", this.test_end_time);
            // this.add_test ("duration", this.test_duration);

            // this.add_test ("changed_signal", this.test_changed_signal);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);

            // var settings = Pomodoro.get_settings ();
            // settings.set_uint ("pomodoro-duration", POMODORO_DURATION);
            // settings.set_uint ("short-break-duration", SHORT_BREAK_DURATION);
            // settings.set_uint ("long-break-duration", LONG_BREAK_DURATION);
            // settings.set_uint ("cycles", CYCLES);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.thaw ();

            // var settings = Pomodoro.get_settings ();
            // settings.revert ();
        }


        /*
         * Tests for constructors
         */

        public void test_new__undefined ()
        {
            var state = Pomodoro.State.STOPPED;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.start_time));
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.end_time));
        }

        public void test_new__pomodoro ()
        {
            var state = Pomodoro.State.POMODORO;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.start_time));
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.end_time));
        }

        public void test_new__short_break ()
        {
            var state = Pomodoro.State.SHORT_BREAK;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.start_time));
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.end_time));
        }

        public void test_new__long_break ()
        {
            var state = Pomodoro.State.LONG_BREAK;
            var time_block = new Pomodoro.TimeBlock (state);

            assert_true (time_block.state == state);
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.start_time));
            assert_true (Pomodoro.Timestamp.is_undefined (time_block.end_time));
        }


        /*
         * Tests for properties
         */

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
            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            assert_true (time_block_2.state == Pomodoro.State.BREAK);

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.STOPPED);
            assert_true (time_block_3.state == Pomodoro.State.STOPPED);
        }

        // public void test_start_time ()
        // {
        // }

        // public void test_end_time ()
        // {
        // }

        // public void test_duration ()
        // {
        // }

        // public void test_session ()
        // {
        // }


        /*
         * Tests for methods
         */

        public void test_move_by__without_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var time_block = new Pomodoro.TimeBlock ();

            var changed_emitted = 0;
            time_block.changed.connect (() => {
                changed_emitted++;
            });

            time_block.set_time_range (Pomodoro.Timestamp.UNDEFINED, now);
            time_block.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);

            time_block.set_time_range (now, Pomodoro.Timestamp.UNDEFINED);
            time_block.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 4);

            time_block.set_time_range (now, now + Pomodoro.Interval.MINUTE);
            time_block.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now + 2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 6);

            time_block.move_by (0);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 6);
        }

        public void test_move_by__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (now + 0 * Pomodoro.Interval.SECOND,
                                  now + 5 * Pomodoro.Interval.SECOND);
            time_block.add_gap (gap_1);

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (now + 10 * Pomodoro.Interval.SECOND,
                                  now + 20 * Pomodoro.Interval.SECOND);
            time_block.add_gap (gap_2);

            time_block.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_1.start_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE + 0 * Pomodoro.Interval.SECOND)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_1.end_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE + 5 * Pomodoro.Interval.SECOND)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_2.start_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE + 10 * Pomodoro.Interval.SECOND)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_2.end_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE + 20 * Pomodoro.Interval.SECOND)
            );
        }

        public void test_move_to ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var time_block = new Pomodoro.TimeBlock ();

            var changed_emitted = 0;
            time_block.changed.connect (() => {
                changed_emitted++;
            });

            // Move +1 minute, while range is not defined.
            time_block.set_time_range (Pomodoro.Timestamp.UNDEFINED, now);
            time_block.move_to (now + Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);

            // Move +1 minute, while range is not defined.
            time_block.set_time_range (now, Pomodoro.Timestamp.UNDEFINED);
            time_block.move_to (now + Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 3);

            // Move +1 minute.
            time_block.set_time_range (now, now + Pomodoro.Interval.MINUTE);
            time_block.move_to (now + Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now + 2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 5);

            // Move -1 minute.
            time_block.set_time_range (now + Pomodoro.Interval.MINUTE, now + 2 * Pomodoro.Interval.MINUTE);
            time_block.move_to (now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now + Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 6);

            // Move 0 minutes.
            time_block.move_to (time_block.start_time);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 6);
        }

        // public void test_has_started ()
        // {
        // }

        // public void test_has_ended ()
        // {
        // }

        public void test_add_gap ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (now + Pomodoro.Interval.MINUTE,
                                       now + 30 * Pomodoro.Interval.MINUTE);

            var changed_emitted = 0;
            time_block.changed.connect (() => {
                changed_emitted++;
            });

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (time_block.start_time + 5 * Pomodoro.Interval.MINUTE,
                                  Pomodoro.Timestamp.UNDEFINED);

            // Expect that `Gap.time_block` is set and that `changed` signal is emitted.
            time_block.add_gap (gap_1);
            assert_true (gap_1.time_block == time_block);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);

            time_block.add_gap (gap_1);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);  // no change

            gap_1.end_time = time_block.start_time + 10 * Pomodoro.Interval.MINUTE;
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);

            // Expect add_gap to keep gaps in order.
            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (time_block.start_time,
                                  time_block.start_time + Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap_2);
            assert_true (time_block.get_last_gap () == gap_1);

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (time_block.start_time + 20 * Pomodoro.Interval.MINUTE,
                                  time_block.start_time + 25 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap_3);
            assert_true (time_block.get_last_gap () == gap_3);
        }

        public void test_remove_gap ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (now + Pomodoro.Interval.MINUTE,
                                       now + 30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (time_block.start_time + 1 * Pomodoro.Interval.MINUTE,
                                  time_block.start_time + 2 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap_1);

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (time_block.start_time + 3 * Pomodoro.Interval.MINUTE,
                                  time_block.start_time + 4 * Pomodoro.Interval.MINUTE);
            time_block.add_gap (gap_2);

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (time_block.start_time + 5 * Pomodoro.Interval.MINUTE,
                                  time_block.start_time + 6 * Pomodoro.Interval.MINUTE);

            var changed_emitted = 0;
            time_block.changed.connect (() => {
                changed_emitted++;
            });

            time_block.remove_gap (gap_1);
            assert_null (gap_1.time_block);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);

            time_block.remove_gap (gap_1);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);

            time_block.remove_gap (gap_2);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);

            time_block.remove_gap (gap_3);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);  // no change
        }

        public void test_calculate_elapsed__without_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock ();
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
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (5 * Pomodoro.Interval.MINUTE, 9 * Pomodoro.Interval.MINUTE);  // 4 minutes

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (15 * Pomodoro.Interval.MINUTE, 17 * Pomodoro.Interval.MINUTE);  // 2 minutes

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (29 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);  // 1 minute

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

        public void test_calculate_elapsed__with_gaps_overlapping ()
        {
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (7 * Pomodoro.Interval.MINUTE, 11 * Pomodoro.Interval.MINUTE);  // 4 minutes

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (10 * Pomodoro.Interval.MINUTE, 13 * Pomodoro.Interval.MINUTE);  // 3 minutes, 1 minute ovrlapping

            time_block.add_gap (gap_1);
            time_block.add_gap (gap_2);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (gap_1.end_time)),
                new GLib.Variant.int64 ((6 - 4) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_elapsed (gap_2.end_time)),
                new GLib.Variant.int64 ((8 - 4 - 3 + 1) * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_remaining__without_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

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
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.STOPPED);
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (2 * Pomodoro.Interval.MINUTE, 9 * Pomodoro.Interval.MINUTE);  // 4 minutes

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (15 * Pomodoro.Interval.MINUTE, 17 * Pomodoro.Interval.MINUTE);  // 2 minutes

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (29 * Pomodoro.Interval.MINUTE, 35 * Pomodoro.Interval.MINUTE);  // 1 minute

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

        public void test_calculate_remaining__with_gaps_overlapping ()
        {
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (7 * Pomodoro.Interval.MINUTE, 11 * Pomodoro.Interval.MINUTE);  // 4 minutes

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (10 * Pomodoro.Interval.MINUTE, 13 * Pomodoro.Interval.MINUTE);  // 3 minutes, 1 minute ovrlapping

            time_block.add_gap (gap_1);
            time_block.add_gap (gap_2);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_1.start_time)),
                new GLib.Variant.int64 ((25 - 2 - 4 - 3 + 1) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_1.end_time)),
                new GLib.Variant.int64 ((25 - 6 - 3 + 1) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_2.start_time)),
                new GLib.Variant.int64 ((25 - 5 - 3) * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.calculate_remaining (gap_2.end_time)),
                new GLib.Variant.int64 ((25 - 8) * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_progress__without_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.start_time),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.start_time - Pomodoro.Interval.MINUTE),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.end_time),
                                          1.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.end_time + Pomodoro.Interval.MINUTE),
                                          1.04,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (10 * Pomodoro.Interval.MINUTE),
                                          0.2,
                                          0.0001);
        }

        public void test_calculate_progress__with_gaps ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.STOPPED);
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (2 * Pomodoro.Interval.MINUTE, 9 * Pomodoro.Interval.MINUTE);  // 4 minutes

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (15 * Pomodoro.Interval.MINUTE, 17 * Pomodoro.Interval.MINUTE);  // 2 minutes

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (29 * Pomodoro.Interval.MINUTE, 35 * Pomodoro.Interval.MINUTE);  // 1 minute

            time_block.add_gap (gap_1);
            time_block.add_gap (gap_2);
            time_block.add_gap (gap_3);

            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.start_time),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (gap_1.end_time),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.start_time - Pomodoro.Interval.MINUTE),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.end_time),
                                          1.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (gap_3.start_time),
                                          1.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (time_block.end_time + Pomodoro.Interval.MINUTE),
                                          1.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (gap_2.end_time),
                                          0.3333,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (gap_2.start_time),
                                          0.3333,
                                          0.0001);
        }

        public void test_calculate_progress__with_ongoing_gap ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.STOPPED);
            time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (25 * Pomodoro.Interval.MINUTE);

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (10 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);

            time_block.add_gap (gap);

            assert_cmpfloat_with_epsilon (time_block.calculate_progress (gap.start_time),
                                          0.25,
                                          0.0001);
            assert_cmpfloat_with_epsilon (time_block.calculate_progress (gap.start_time + Pomodoro.Interval.MINUTE),
                                          0.25,
                                          0.0001);
        }

        public void test_calculate_progress__with_gaps_overlapping ()
        {
            // TODO
        }

        // public void test_calculate_progress_inv__without_gaps ()
        // {
        //     var time_block = new Pomodoro.TimeBlock ();
        //     time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (0.0)),
        //         new GLib.Variant.int64 (time_block.start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (1.0)),
        //         new GLib.Variant.int64 (time_block.end_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (0.2)),
        //         new GLib.Variant.int64 (time_block.start_time + 5 * Pomodoro.Interval.MINUTE)
        //     );
        // }

        // public void test_calculate_progress_inv__with_gaps ()
        // {
        //     var time_block = new Pomodoro.TimeBlock (Pomodoro.State.STOPPED);
        //     time_block.set_time_range (5 * Pomodoro.Interval.MINUTE, 30 * Pomodoro.Interval.MINUTE);

        //     var gap_1 = new Pomodoro.Gap ();
        //     gap_1.set_time_range (2 * Pomodoro.Interval.MINUTE, 6 * Pomodoro.Interval.MINUTE);  // 1 minutes

        //     var gap_2 = new Pomodoro.Gap ();
        //     gap_2.set_time_range (15 * Pomodoro.Interval.MINUTE, 17 * Pomodoro.Interval.MINUTE);  // 2 minutes

        //     var gap_3 = new Pomodoro.Gap ();
        //     gap_3.set_time_range (28 * Pomodoro.Interval.MINUTE, 40 * Pomodoro.Interval.MINUTE);  // 2 minutes

        //     time_block.add_gap (gap_1);
        //     time_block.add_gap (gap_2);
        //     time_block.add_gap (gap_3);

        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (0.0)),
        //         new GLib.Variant.int64 (gap_1.end_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (0.25)),
        //         new GLib.Variant.int64 (time_block.start_time + (1 + 5) * Pomodoro.Interval.MINUTE)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (0.5)),
        //         new GLib.Variant.int64 (time_block.start_time + (1 + 9 + 2 + 1) * Pomodoro.Interval.MINUTE)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (0.75)),
        //         new GLib.Variant.int64 (time_block.start_time + (1 + 9 + 2 + 6) * Pomodoro.Interval.MINUTE)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (time_block.calculate_progress_inv (1.0)),
        //         new GLib.Variant.int64 (gap_3.start_time)
        //     );
        // }

        // public void test_calculate_progress_inv__with_gaps_overlapping ()
        // {
            // TODO
        // }


        // public void test_changed_signal ()
        // {
        // }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimeBlockTest ()
    );
}
