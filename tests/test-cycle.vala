namespace Tests
{
    public class CycleTest : Tests.TestSuite
    {
        public CycleTest ()
        {
            this.add_test ("remove", this.test_remove);

            this.add_test ("get_weight", this.test_get_weight);
            this.add_test ("get_completion_time", this.test_get_completion_time);
            this.add_test ("get_completion_time__with_gaps", this.test_get_completion_time__with_gaps);

            this.add_test ("calculate_progress__scheduled", this.test_calculate_progress__scheduled);
            this.add_test ("calculate_progress__in_progress", this.test_calculate_progress__in_progress);
            this.add_test ("calculate_progress__completed", this.test_calculate_progress__completed);
            this.add_test ("calculate_progress__with_gaps", this.test_calculate_progress__with_gaps);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        public void test_remove ()
        {
            var removed_emitted = 0;
            var weak_notify_emitted = 0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.weak_ref (() => { weak_notify_emitted++; });

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block);
            cycle.removed.connect (() => { removed_emitted++; });

            assert_cmpuint (time_block.ref_count, GLib.CompareOperator.EQ, 2);
            cycle.remove (time_block);
            assert_false (cycle.contains (time_block));
            assert_cmpuint (time_block.ref_count, GLib.CompareOperator.EQ, 1);

            time_block = null;
            assert_cmpuint (removed_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (weak_notify_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_get_weight ()
        {
            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.UNCOMPLETED,
                    weight = 1.0,
                }
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 1.0,
                }
            );

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_3.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 0.0,
                }
            );

            var cycle = new Pomodoro.Cycle ();

            cycle.append (time_block_1);
            assert_cmpfloat_with_epsilon (cycle.get_weight (),
                                          0.0,
                                          0.0001);

            cycle.append (time_block_2);
            assert_cmpfloat_with_epsilon (cycle.get_weight (),
                                          1.0,
                                          0.0001);

            cycle.append (time_block_3);
            assert_cmpfloat_with_epsilon (cycle.get_weight (),
                                          1.0,
                                          0.0001);
        }

        public void test_get_completion_time ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.UNCOMPLETED,
                    weight = 1.0,
                    completion_time = now + 20 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 1.0,
                    completion_time = now + 25 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_3.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();

            cycle.append (time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (cycle.get_completion_time ()),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );

            cycle.append (time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (cycle.get_completion_time ()),
                new GLib.Variant.int64 (now + 25 * Pomodoro.Interval.MINUTE)
            );

            cycle.append (time_block_3);
            assert_cmpvariant (
                new GLib.Variant.int64 (cycle.get_completion_time ()),
                new GLib.Variant.int64 (now + 25 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_get_completion_time__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, now + 7 * Pomodoro.Interval.MINUTE);  // 2 minutes

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.IN_PROGRESS,
                    weight = 1.0,
                    intended_duration = 25 * Pomodoro.Interval.MINUTE,
                    completion_time = now + 22 * Pomodoro.Interval.MINUTE,
                }
            );
            time_block_1.add_gap (gap);
            time_block_1.set_time_range (now, now + 27 * Pomodoro.Interval.MINUTE);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block_1);
            cycle.append (time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (cycle.get_completion_time ()),
                new GLib.Variant.int64 (now + 22 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_progress__scheduled ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 1.0,
                    completion_time = now + 20 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_2.set_time_range (now + 25 * Pomodoro.Interval.MINUTE, now + 30 * Pomodoro.Interval.MINUTE);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block_1);
            cycle.append (time_block_2);

            assert_true (cycle.calculate_progress (time_block_1.start_time).is_nan ());
            assert_true (cycle.calculate_progress (time_block_1.end_time).is_nan ());
            assert_true (cycle.calculate_progress (time_block_2.end_time).is_nan ());
        }

        public void test_calculate_progress__in_progress ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.UNCOMPLETED,
                    weight = 1.0,
                    completion_time = now + 20 * Pomodoro.Interval.MINUTE,
                    intended_duration = 25 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, now + 30 * Pomodoro.Interval.MINUTE);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.IN_PROGRESS,
                    weight = 1.0,
                    completion_time = now + 25 * Pomodoro.Interval.MINUTE,
                    intended_duration = 25 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_3.set_time_range (now + 30 * Pomodoro.Interval.MINUTE, now + 35 * Pomodoro.Interval.MINUTE);
            time_block_3.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                    intended_duration = 5 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block_1);
            cycle.append (time_block_2);
            cycle.append (time_block_3);

            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_1.end_time),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_2.start_time + 5 * Pomodoro.Interval.MINUTE),
                                          0.25,
                                          0.0001);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_2.end_time),
                                          1.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_3.end_time),
                                          1.0,
                                          0.0001);
        }

        /*
        public void test_calculate_progress__break ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.UNCOMPLETED,
                    weight = 1.0,
                    completion_time = now + 20 * Pomodoro.Interval.MINUTE,
                    intended_duration = 25 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_2.set_time_range (now + 30 * Pomodoro.Interval.MINUTE, now + 35 * Pomodoro.Interval.MINUTE);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.SCHEDULED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                    intended_duration = 5 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block_1);
            cycle.append (time_block_2);

            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_1.end_time),
                                          double.NAN,
                                          0.0001);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_2.end_time),
                                          double.NAN,
                                          0.0001);


            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_2.start_time + 5 * Pomodoro.Interval.MINUTE),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_2.end_time),
                                          0.0,
                                          0.0001);
        }
        */

        public void test_calculate_progress__completed ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.COMPLETED,
                    weight = 1.0,
                    completion_time = now + 20 * Pomodoro.Interval.MINUTE,
                    intended_duration = 25 * Pomodoro.Interval.MINUTE,
                }
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_2.set_time_range (now + 25 * Pomodoro.Interval.MINUTE, now + 30 * Pomodoro.Interval.MINUTE);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.COMPLETED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                    intended_duration = 5 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block_1);
            cycle.append (time_block_2);

            assert_cmpfloat_with_epsilon (cycle.calculate_progress (time_block_2.end_time),
                                          1.0,
                                          0.0001);
        }

        public void test_calculate_progress__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.COMPLETED,
                    weight = 1.0,
                    completion_time = now + 20 * Pomodoro.Interval.MINUTE,
                    intended_duration = 25 * Pomodoro.Interval.MINUTE,
                }
            );
            var gap = new Pomodoro.Gap ();
            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);
            time_block_1.add_gap (gap);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_2.set_time_range (now + 25 * Pomodoro.Interval.MINUTE, now + 30 * Pomodoro.Interval.MINUTE);
            time_block_2.set_meta (
                Pomodoro.TimeBlockMeta () {
                    status = Pomodoro.TimeBlockStatus.COMPLETED,
                    weight = 0.0,
                    completion_time = now + 29 * Pomodoro.Interval.MINUTE,
                    intended_duration = 5 * Pomodoro.Interval.MINUTE,
                }
            );

            var cycle = new Pomodoro.Cycle ();
            cycle.append (time_block_1);
            cycle.append (time_block_2);

            assert_cmpfloat_with_epsilon (cycle.calculate_progress (gap.start_time + Pomodoro.Interval.MINUTE),
                                          0.25,
                                          0.0001);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CycleTest ()
    );
}
