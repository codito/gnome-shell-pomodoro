namespace Tests
{
    private double EPSILON = 0.0001;


    public abstract class BaseSchedulerTest : Tests.TestSuite
    {
        protected Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.thaw ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        public Pomodoro.Session create_session (Pomodoro.Scheduler scheduler)
        {
            var session = new Pomodoro.Session.from_template (scheduler.session_template);
            session.@foreach (
                (time_block) => {
                    time_block.set_intended_duration (time_block.duration);
                    time_block.set_completion_time (scheduler.calculate_time_block_completion_time (time_block));
                }
            );

            return session;
        }
    }

    public class SimpleSchedulerTest : BaseSchedulerTest
    {
        public SimpleSchedulerTest ()
        {
            this.add_test ("calculate_time_block_completion_time", this.test_calculate_time_block_completion_time);
            this.add_test ("calculate_time_block_completion_time__with_gaps", this.test_calculate_time_block_completion_time__with_gaps);

            this.add_test ("calculate_time_block_score__pomodoro", this.test_calculate_time_block_score__pomodoro);
            this.add_test ("calculate_time_block_score__short_break", this.test_calculate_time_block_score__short_break);
            this.add_test ("calculate_time_block_score__long_break", this.test_calculate_time_block_score__long_break);

            this.add_test ("calculate_time_block_weight__with_gaps", this.test_calculate_time_block_weight__with_gaps);

            this.add_test ("is_time_block_completed__pomodoro", this.test_is_time_block_completed__pomodoro);
            this.add_test ("is_time_block_completed__short_break", this.test_is_time_block_completed__short_break);
            this.add_test ("is_time_block_completed__long_break", this.test_is_time_block_completed__long_break);

            this.add_test ("resolve_context__update_state", this.test_resolve_context__update_state);
            this.add_test ("resolve_context__update_timestamp", this.test_resolve_context__update_timestamp);
            this.add_test ("resolve_context__completed_pomodoro", this.test_resolve_context__completed_pomodoro);
            this.add_test ("resolve_context__completed_short_break", this.test_resolve_context__completed_short_break);
            this.add_test ("resolve_context__completed_long_break", this.test_resolve_context__completed_long_break);
            this.add_test ("resolve_context__in_progress_pomodoro", this.test_resolve_context__in_progress_pomodoro);
            this.add_test ("resolve_context__in_progress_short_break", this.test_resolve_context__in_progress_short_break);
            this.add_test ("resolve_context__in_progress_long_break", this.test_resolve_context__in_progress_long_break);
            this.add_test ("resolve_context__uncompleted_pomodoro", this.test_resolve_context__uncompleted_pomodoro);
            this.add_test ("resolve_context__uncompleted_short_break", this.test_resolve_context__uncompleted_short_break);
            this.add_test ("resolve_context__uncompleted_long_break", this.test_resolve_context__uncompleted_long_break);
            this.add_test ("resolve_context__needs_long_break", this.test_resolve_context__needs_long_break);

            this.add_test ("resolve_time_block__pomodoro", this.test_resolve_time_block__pomodoro);
            this.add_test ("resolve_time_block__short_break", this.test_resolve_time_block__short_break);
            this.add_test ("resolve_time_block__long_break", this.test_resolve_time_block__long_break);
            this.add_test ("resolve_time_block__completed_session", this.test_resolve_time_block__completed_session);

            this.add_test ("reschedule_session__populate", this.test_reschedule_session__populate);
            this.add_test ("reschedule_session__completed_session", this.test_reschedule_session__completed_session);
            this.add_test ("reschedule_session__uncompleted_pomodoro", this.test_reschedule_session__uncompleted_pomodoro);
            this.add_test ("reschedule_session__uncompleted_short_break", this.test_reschedule_session__uncompleted_short_break);
            this.add_test ("reschedule_session__uncompleted_long_break", this.test_reschedule_session__uncompleted_long_break);
            this.add_test ("reschedule_session__skip_long_break", this.test_reschedule_session__skip_long_break);
            this.add_test ("reschedule_session__resume_session_1", this.test_reschedule_session__resume_session_1);
            this.add_test ("reschedule_session__resume_session_2", this.test_reschedule_session__resume_session_2);
        }

        public void test_calculate_time_block_completion_time ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 30 * Pomodoro.Interval.SECOND);
            time_block_1.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_1)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now, now + 20 * Pomodoro.Interval.MINUTE);
            time_block_2.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_2)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_3.set_time_range (now, now + 50 * Pomodoro.Interval.MINUTE);
            time_block_3.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_3)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var time_block_4 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_4.set_time_range (now, now + 10 * Pomodoro.Interval.MINUTE);
            time_block_4.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_4)),
                new GLib.Variant.int64 (now + 4 * Pomodoro.Interval.MINUTE)
            );

            var time_block_5 = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block_5.set_time_range (now, now + 5 * Pomodoro.Interval.SECOND);
            time_block_5.set_intended_duration (5 * Pomodoro.Interval.SECOND);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block_5)),
                new GLib.Variant.int64 (now + 4 * Pomodoro.Interval.SECOND)
            );
        }

        public void test_calculate_time_block_completion_time__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            var gap = new Pomodoro.Gap ();
            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);
            time_block.add_gap (gap);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 20 * Pomodoro.Interval.MINUTE)
            );

            gap.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, now + 15 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 30 * Pomodoro.Interval.MINUTE)
            );

            time_block.set_time_range (now, now + 35 * Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (scheduler.calculate_time_block_completion_time (time_block)),
                new GLib.Variant.int64 (now + 30 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_calculate_time_block_score__pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);

            time_block.set_time_range (now, now + 19 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 20 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + (25 + 19) * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 1.0, EPSILON);

            time_block.set_time_range (now, now + (25 + 20) * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 2.0, EPSILON);
        }

        public void test_calculate_time_block_score__short_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);

            time_block.set_time_range (now, now + 4 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);
        }

        public void test_calculate_time_block_score__long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var score = 0.0;

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_intended_duration (15 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);

            time_block.set_time_range (now, now + 12 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);

            time_block.set_time_range (now, now + 15 * Pomodoro.Interval.MINUTE);
            score = scheduler.calculate_time_block_score (time_block, time_block.end_time);
            assert_cmpfloat_with_epsilon (score, 0.0, EPSILON);
        }

        /**
         * Ignore ongoing gap when calculating weight.
         */
        public void test_calculate_time_block_weight__with_gaps ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block_1.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            assert_cmpfloat_with_epsilon (scheduler.calculate_time_block_weight (time_block_1), 1.0, EPSILON);

            var gap_1 = new Pomodoro.Gap ();
            gap_1.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);
            time_block_1.add_gap (gap_1);
            assert_cmpfloat_with_epsilon (scheduler.calculate_time_block_weight (time_block_1), 1.0, EPSILON);

            gap_1.set_time_range (now + 5 * Pomodoro.Interval.MINUTE, now + 15 * Pomodoro.Interval.MINUTE);
            time_block_1.set_completion_time (now + 30 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (scheduler.calculate_time_block_weight (time_block_1), 0.0, EPSILON);

            time_block_1.set_time_range (now, now + 35 * Pomodoro.Interval.MINUTE);
            assert_cmpfloat_with_epsilon (scheduler.calculate_time_block_weight (time_block_1), 1.0, EPSILON);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now, now + 25 * Pomodoro.Interval.MINUTE);
            time_block_2.set_intended_duration (25 * Pomodoro.Interval.MINUTE);
            time_block_2.set_completion_time (now + 20 * Pomodoro.Interval.MINUTE);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var gap_2 = new Pomodoro.Gap ();
            gap_2.set_time_range (now + 22 * Pomodoro.Interval.MINUTE, Pomodoro.Timestamp.UNDEFINED);
            time_block_2.add_gap (gap_2);
            assert_cmpfloat_with_epsilon (scheduler.calculate_time_block_weight (time_block_2), 1.0, EPSILON);

            var gap_3 = new Pomodoro.Gap ();
            gap_3.set_time_range (now, now + 22 * Pomodoro.Interval.MINUTE);
            time_block_2.add_gap (gap_3);
            time_block_2.set_time_range (now, now + (25 + 22) * Pomodoro.Interval.MINUTE);
            time_block_2.set_completion_time (now + (20 + 22) * Pomodoro.Interval.MINUTE);

            assert_cmpfloat_with_epsilon (scheduler.calculate_time_block_weight (time_block_2), 1.0, EPSILON);
        }


        /**
         * Time-block should complete at least 80% of intended duration, and not be shorter than 1 minute.
         */

        public void test_is_time_block_completed__pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);
            var time_block = session.get_nth_time_block (0);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var timestamp_1 = time_block.start_time + 20 * Pomodoro.Interval.MINUTE - Pomodoro.Interval.SECOND;
            assert_false (scheduler.is_time_block_completed (time_block, timestamp_1));

            var timestamp_2 = time_block.start_time + 20 * Pomodoro.Interval.MINUTE;
            assert_true (scheduler.is_time_block_completed (time_block, timestamp_2));
        }

        public void test_is_time_block_completed__short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);
            var time_block = session.get_nth_time_block (1);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var timestamp_1 = time_block.start_time + 4 * Pomodoro.Interval.MINUTE - Pomodoro.Interval.SECOND;
            assert_false (scheduler.is_time_block_completed (time_block, timestamp_1));

            var timestamp_2 = time_block.start_time + 4 * Pomodoro.Interval.MINUTE;
            assert_true (scheduler.is_time_block_completed (time_block, timestamp_2));
        }

        public void test_is_time_block_completed__long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = this.create_session (scheduler);
            var time_block = session.get_last_time_block ();
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var timestamp_1 = time_block.start_time + 4 * Pomodoro.Interval.MINUTE - Pomodoro.Interval.SECOND;
            assert_false (scheduler.is_time_block_completed (time_block, timestamp_1));

            var timestamp_2 = time_block.start_time + 12 * Pomodoro.Interval.MINUTE;
            assert_true (scheduler.is_time_block_completed (time_block, timestamp_2));
        }


        /**
         * Expect `Scheduler.resolve_state()` to copy current time-block state into scheduler context.
         */
        public void test_resolve_context__update_state ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            Pomodoro.State[] states = {
                Pomodoro.State.UNDEFINED,
                Pomodoro.State.POMODORO,
                Pomodoro.State.SHORT_BREAK,
                Pomodoro.State.LONG_BREAK
            };

            foreach (var state in states)
            {
                var context = Pomodoro.SchedulerContext ();
                var time_block = new Pomodoro.TimeBlock (state);

                scheduler.resolve_context (time_block, time_block.end_time, ref context);
                assert_true (context.state == state);
            }
        }

        public void test_resolve_context__update_timestamp ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            int64[] timestamps = {
                now + Pomodoro.Interval.MINUTE,
                now + 5 * Pomodoro.Interval.MINUTE,
                now + 10 * Pomodoro.Interval.MINUTE
            };

            foreach (var timestamp in timestamps)
            {
                var context = Pomodoro.SchedulerContext ();
                var time_block = new Pomodoro.TimeBlock ();

                time_block.set_time_range (timestamp, timestamp + Pomodoro.Interval.MINUTE);

                scheduler.resolve_context (time_block, time_block.end_time, ref context);
                assert_cmpvariant (
                    new GLib.Variant.int64 (context.timestamp),
                    new GLib.Variant.int64 (time_block.end_time)
                );
            }
        }

        /**
         * Completing a pomodoro should mark session as completed.
         */
        public void test_resolve_context__completed_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_time_range (now, now + 9 * Pomodoro.Interval.MINUTE);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                score = 0.0,
            };

            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 2.0,
            };
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__completed_short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                score = 1.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.SHORT_BREAK,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        /**
         * Completing a long break should mark session as completed.
         */
        public void test_resolve_context__completed_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var cycles = (double) this.session_template.cycles;
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                is_session_completed = false,
                needs_long_break = true,
                score = cycles,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.LONG_BREAK,
                is_session_completed = true,
                needs_long_break = false,
                score = cycles,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__in_progress_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 9 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 4 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                score = 0.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 2.0,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__in_progress_short_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_time_range (now, now + 5 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 4 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                score = 1.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.SHORT_BREAK,
                score = 1.0,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__in_progress_long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var cycles = (double) this.session_template.cycles;
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_time_range (now, now + 15 * Pomodoro.Interval.MINUTE);
            time_block.set_intended_duration (12 * Pomodoro.Interval.MINUTE);
            time_block.set_completion_time (now + 12 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                is_session_completed = false,
                needs_long_break = true,
                score = cycles,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.LONG_BREAK,
                is_session_completed = true,
                needs_long_break = false,
                score = cycles,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_pomodoro ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_time_range (now, now + 3 * Pomodoro.Interval.MINUTE);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                score = 0.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                score = 0.0,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                score = 1.0,
            };
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state     = Pomodoro.State.SHORT_BREAK,
                score     = 1.0,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__uncompleted_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.LONG_BREAK);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                is_session_completed = false,
                needs_long_break = true,
                score = 4.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.LONG_BREAK,
                is_session_completed = false,
                needs_long_break = true,
                score = 4.0,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        public void test_resolve_context__needs_long_break ()
        {
            var now = Pomodoro.Timestamp.peek ();
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var cycles = (double) this.session_template.cycles;
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            time_block.set_intended_duration (5 * Pomodoro.Interval.MINUTE);
            time_block.set_time_range (now, now + 4 * Pomodoro.Interval.MINUTE);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
                needs_long_break = false,
                score = cycles - 1.0,
            };

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                needs_long_break = true,
                score = cycles,
            };
            scheduler.resolve_context (time_block, time_block.end_time, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }


        public void test_resolve_time_block__pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);

            var context_1 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.UNDEFINED,
            };
            var time_block_1 = scheduler.resolve_time_block (context_1);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);

            var context_2 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.SHORT_BREAK,
            };
            var time_block_2 = scheduler.resolve_time_block (context_2);
            assert_true (time_block_2.state == Pomodoro.State.POMODORO);
        }

        public void test_resolve_time_block__short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
            };

            var time_block = scheduler.resolve_time_block (context);
            assert_true (time_block.state == Pomodoro.State.SHORT_BREAK);
        }

        public void test_resolve_time_block__long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                needs_long_break = true,
            };
            var time_block = scheduler.resolve_time_block (context);
            assert_true (time_block.state == Pomodoro.State.LONG_BREAK);
        }

        /**
         * Expect `resolve_time_block()` to return null for a completed session.
         */
        public void test_resolve_time_block__completed_session ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.LONG_BREAK,
                score = (double) this.session_template.cycles,
                is_session_completed = true,
            };
            var time_block = scheduler.resolve_time_block (context);
            assert_null (time_block);
        }


        /**
         * Populate empty session using scheduler.
         */
        public void test_reschedule_session__populate ()
        {
            var timestamp = Pomodoro.Timestamp.advance (0) + Pomodoro.Interval.MINUTE;
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session = new Pomodoro.Session ();

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            scheduler.reschedule_session (session, null, timestamp);

            assert_cmpuint (session.get_cycles ().length (), GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (timestamp)
            );

            var time_block_1 = session.get_nth_time_block (0);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);

            var time_block_2 = session.get_nth_time_block (1);
            assert_true (time_block_2.state == Pomodoro.State.SHORT_BREAK);

            var last_time_block = session.get_last_time_block ();
            assert_true (last_time_block.state == Pomodoro.State.LONG_BREAK);

            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Rescheduling a session that has completed long-break shouldn't do anything.
         *
         * No upcoming time-block should force `SessionManager` to start new session.
         */
        public void test_reschedule_session__completed_session ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);
            session.@foreach (
                (time_block) => {
                    time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                }
            );

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            scheduler.reschedule_session (session, null, session.end_time);

            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 0);
        }

        public void test_reschedule_session__uncompleted_pomodoro ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            time_block_1.set_time_range (time_block_1.start_time,
                                         time_block_1.start_time + 5 * Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = session.get_nth_time_block (1);

            var now = time_block_1.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, time_block_2, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (session.get_cycles ().length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);
        }

        public void test_reschedule_session__uncompleted_short_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_2 = session.get_nth_time_block (1);
            time_block_2.set_time_range (time_block_2.start_time,
                                         time_block_2.start_time + 2 * Pomodoro.Interval.MINUTE);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_3 = session.get_nth_time_block (2);

            var now = time_block_2.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, time_block_3, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_3.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpuint (session.get_cycles ().length (), GLib.CompareOperator.EQ, this.session_template.cycles);
        }

        /**
         * If long break has been skipped expect extra cycle to be created. New time-blocks should be
         * marked as "is_extra" and the extra cycle should have not be visible until started.
         */
        public void test_reschedule_session__uncompleted_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);
            session.@foreach (
                (time_block) => {
                    time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                }
            );

            var time_block = session.get_last_time_block ();
            time_block.set_time_range (time_block.start_time,
                                       time_block.start_time + 2 * Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var now = time_block.end_time;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, now);

            // Expect extra cycle
            var extra_pomodoro = session.get_next_time_block (time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_pomodoro.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (extra_pomodoro.state == Pomodoro.State.POMODORO);
            assert_true (extra_pomodoro.get_is_extra ());
            assert_true (extra_pomodoro.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

            var extra_long_break = session.get_next_time_block (extra_pomodoro);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_long_break.start_time),
                new GLib.Variant.int64 (extra_pomodoro.end_time)
            );
            assert_true (extra_long_break.state == Pomodoro.State.LONG_BREAK);
            assert_true (extra_long_break.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

            var cycles = session.get_cycles ();
            assert_cmpuint (cycles.length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);

            var extra_cycle = cycles.last ().data;
            assert_true (extra_cycle.is_extra ());
            assert_false (extra_cycle.is_visible ());

            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_true (extra_cycle.is_extra ());
            assert_true (extra_cycle.is_visible ());

            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (extra_cycle.is_extra ());
            assert_false (extra_cycle.is_visible ());
        }

        /**
         * Skip a long-break while is still in progress.
         */
        public void test_reschedule_session__skip_long_break ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);
            session.@foreach (
                (time_block) => {
                    time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                }
            );

            var time_block = session.get_last_time_block ();
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var now = time_block.start_time + 2 * Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, null, now);

            // Expect extra cycle
            var extra_pomodoro = session.get_next_time_block (time_block);
            assert_nonnull (extra_pomodoro);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_pomodoro.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (extra_pomodoro.state == Pomodoro.State.POMODORO);
            assert_true (extra_pomodoro.get_is_extra ());
            assert_true (extra_pomodoro.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

            var extra_long_break = session.get_next_time_block (extra_pomodoro);
            assert_nonnull (extra_long_break);
            assert_cmpvariant (
                new GLib.Variant.int64 (extra_long_break.start_time),
                new GLib.Variant.int64 (extra_pomodoro.end_time)
            );
            assert_true (extra_long_break.state == Pomodoro.State.LONG_BREAK);
            assert_true (extra_long_break.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

            var cycles = session.get_cycles ();
            assert_cmpuint (cycles.length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);

            var extra_cycle = cycles.last ().data;
            assert_true (extra_cycle.is_extra ());
            assert_false (extra_cycle.is_visible ());

            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_true (extra_cycle.is_extra ());
            assert_true (extra_cycle.is_visible ());

            extra_pomodoro.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (extra_cycle.is_extra ());
            assert_false (extra_cycle.is_visible ());
        }

        /**
         * Simulate resuming session after stopping the timer.
         *
         * Simplest case, where we continue with next time-block.
         */
        public void test_reschedule_session__resume_session_1 ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            time_block_1.set_time_range (time_block_1.start_time,
                                         time_block_1.start_time + 5 * Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = session.get_nth_time_block (1);

            var now = time_block_1.end_time + Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, time_block_2, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );

            var cycles = session.get_cycles ();
            assert_cmpuint (cycles.length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);
            assert_true (cycles.first ().data.contains (time_block_2));

            time_block_2.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_false (cycles.first ().data.is_visible ());
            assert_true (cycles.last ().data.is_visible ());
        }

        /**
         * Simulate resuming session after stopping the timer.
         *
         * Real-world use, where we insert a new pomodoro.
         */
        public void test_reschedule_session__resume_session_2 ()
        {
            var scheduler = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            var session   = this.create_session (scheduler);

            var time_block_1 = session.get_nth_time_block (0);
            time_block_1.set_time_range (time_block_1.start_time,
                                         time_block_1.start_time + 5 * Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            session.insert_after (time_block_2, time_block_1);

            var now = time_block_1.end_time + Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            scheduler.reschedule_session (session, time_block_2, now);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );

            var cycles = session.get_cycles ();
            assert_cmpuint (cycles.length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);
            assert_false (cycles.nth_data (0).is_visible ());
            assert_true (cycles.nth_data (1).contains (time_block_2));
            assert_true (cycles.nth_data (1).is_visible ());
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SimpleSchedulerTest ()
    );
}
