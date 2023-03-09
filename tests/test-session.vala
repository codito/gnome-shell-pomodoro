namespace Tests
{
    // private uint8[] list_states (Pomodoro.Session session)
    // {
    //     uint8[] states = {};

    //     session.@foreach ((time_block) => {
    //         states += (uint8) time_block.state;
    //     });

    //     return states;
    // }

    // delegate bool FilterFunc (Pomodoro.TimeBlock time_block);


    private void mark_time_blocks_completed (Pomodoro.Session session,
                                             uint             n)
    {
        unowned Pomodoro.TimeBlock time_block;

        for (var index = 0; index < n; index++)
        {
            time_block = session.get_nth_time_block (index);
            // time_block.status = Pomodoro.TimeBlockStatus.COMPLETED;

            session.mark_time_block_ended (time_block, true, time_block.end_time);
        }
    }


    private uint count_pomodoros (Pomodoro.Session session)
    {
        var count = 0;

        session.@foreach (time_block => {
            if (time_block.state == Pomodoro.State.POMODORO) {
                count++;
            }
        });

        return count;
    }


    public class SessionTest : Tests.TestSuite
    {
        private Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        public SessionTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new_from_template", this.test_new_from_template);

            this.add_test ("populate", this.test_populate);

            // TODO: Tests methods for modifying history
            // this.add_test ("prepend", this.test_prepend);
            // this.add_test ("append", this.test_append);
            // this.add_test ("insert", this.test_insert);
            // this.add_test ("insert_before", this.test_insert_before);
            // this.add_test ("insert_after", this.test_insert_after);
            // this.add_test ("replace", this.test_replace);

            this.add_test ("get_first_time_block", this.test_get_first_time_block);
            this.add_test ("get_last_time_block", this.test_get_last_time_block);
            this.add_test ("get_next_time_block", this.test_get_next_time_block);
            this.add_test ("get_previous_time_block", this.test_get_previous_time_block);

            this.add_test ("get_cycles_count", this.test_get_cycles_count);

            // TODO: Tests methods for modifying ongoing session
            // this.add_test ("extend", this.test_extend);
            // this.add_test ("shorten", this.test_shorten);

            // TODO: Tests for signals
            // this.add_test ("changed_signal", this.test_changed_signal);
            // this.add_test ("time_block_added_signal", this.test_time_block_added_signal);
            // this.add_test ("time_block_removed_signal", this.test_time_block_removed_signal);
            // this.add_test ("time_block_changed_signal", this.test_time_block_changed_signal);

            // TODO: Tests for propagating changes between blocks
            // this.add_test ("time_block_set_start_time", this.test_time_block_set_start_time);
            // this.add_test ("time_block_set_end_time", this.test_time_block_set_end_time);
            // this.add_test ("time_block_set_time_range", this.test_time_block_set_end_time);

            // this.add_test ("reschedule__strict", this.test_reschedule__strict);
            // this.add_test ("reschedule__strict__after_unscheduled_pomodoro", this.test_reschedule__strict__after_unscheduled_pomodoro);
            // this.add_test ("reschedule__strict__after_unscheduled_short_break", this.test_reschedule__strict__after_unscheduled_short_break);
            // this.add_test ("reschedule__strict__after_unscheduled_long_break", this.test_reschedule__strict__after_unscheduled_long_break);
            // this.add_test ("reschedule__strict__after_in_progress_pomodoro", this.test_reschedule__strict__after_in_progress_pomodoro);
            // this.add_test ("reschedule__strict__after_in_progress_short_break", this.test_reschedule__strict__after_in_progress_short_break);
            // this.add_test ("reschedule__strict__after_in_progress_long_break", this.test_reschedule__strict__after_in_progress_long_break);
            // this.add_test ("reschedule__strict__after_completed_pomodoro", this.test_reschedule__strict__after_completed_pomodoro);
            // this.add_test ("reschedule__strict__after_completed_short_break", this.test_reschedule__strict__after_completed_short_break);
            // this.add_test ("reschedule__strict__after_completed_long_break", this.test_reschedule__strict__after_completed_long_break);
            // this.add_test ("reschedule__strict__after_uncompleted_pomodoro", this.test_reschedule__strict__after_uncompleted_pomodoro);
            // this.add_test ("reschedule__strict__after_uncompleted_short_break", this.test_reschedule__strict__after_uncompleted_short_break);
            // this.add_test ("reschedule__strict__after_uncompleted_long_break", this.test_reschedule__strict__after_uncompleted_long_break);
            // this.add_test ("reschedule__strict__template_change", this.test_reschedule__strict__template_change);

            this.add_test ("reschedule__lenient", this.test_reschedule__lenient);

            // TODO: methods for saving / restoring in db
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            // var settings = Pomodoro.get_settings ();
            // settings.set_uint ("pomodoro-duration", POMODORO_DURATION);
            // settings.set_uint ("short-break-duration", SHORT_BREAK_DURATION);
            // settings.set_uint ("long-break-duration", LONG_BREAK_DURATION);
            // settings.set_uint ("pomodoros-per-session", CYCLES_PER_SESSION);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        /**
         * Check constructor `Session()`.
         *
         * Expect session not to have any time-blocks.
         */
        public void test_new ()
        {
            var session = new Pomodoro.Session ();

            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MIN)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MAX)
            );

            var first_time_block = session.get_first_time_block ();
            assert_null (first_time_block);

            var last_time_block = session.get_last_time_block ();
            assert_null (last_time_block);
        }

        /**
         * Check constructor `Session.from_template()`.
         *
         * Expect session to have time-blocks defined according to settings.
         */
        public void test_new_from_template ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var template = this.session_template;
            var session = new Pomodoro.Session.from_template (template);
            // Pomodoro.TimeBlock[] time_blocks = {};

            // session.@foreach ((time_block) => {
            //     time_blocks += time_block;
            // });

            // assert_true (
            //     time_blocks.length == template.cycles * 2
            // );
            // for (uint cycle=0; cycle < template.cycles; cycle++) {
            //     var pomodoro = time_blocks[cycle * 2 + 0];
            //     var break_ = time_blocks[cycle * 2 + 1];

            //     assert_true (pomodoro.state == Pomodoro.State.POMODORO);
            //     assert_true (break_.state == Pomodoro.State.BREAK);
            // }

            assert_cmpuint (session.get_cycles_count (), GLib.CompareOperator.EQ, template.cycles);

            // assert_cmpmem (
            //     list_session_states (session),
            //     {
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK
            //     }
            // );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (
                    session.start_time + (
                        template.pomodoro_duration * template.cycles +
                        template.short_break_duration * (template.cycles - 1) +
                        template.long_break_duration
                    )
                )
            );
        }

        public void test_get_cycles_count ()
        {
            var session_0 = new Pomodoro.Session ();
            assert_cmpuint (session_0.get_cycles_count (), GLib.CompareOperator.EQ, 0);

            var session_1 = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    cycles = 1
                }
            );
            assert_cmpuint (session_1.get_cycles_count (), GLib.CompareOperator.EQ, 1);

            var session_2 = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    cycles = 2
                }
            );
            assert_cmpuint (session_2.get_cycles_count (), GLib.CompareOperator.EQ, 2);

            // TODO Test with session starting with a break

            // TODO Test with session starting with undefined block
        }

        /**
         * Check `Session.populate()`.
         */
        public void test_populate ()
        {
            unowned Pomodoro.TimeBlock time_block;

            var template = Pomodoro.SessionTemplate () {
                pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
                short_break_duration = 5 * Pomodoro.Interval.MINUTE,
                long_break_duration = 15 * Pomodoro.Interval.MINUTE,
                cycles = 4
            };
            var now = Pomodoro.Timestamp.advance (0);
            var session = new Pomodoro.Session ();

            session.populate (template, now);
            assert_cmpuint (session.get_cycles_count (), GLib.CompareOperator.EQ, template.cycles);

            time_block = session.get_nth_time_block (0);
            assert_true (time_block.duration == template.pomodoro_duration);

            time_block = session.get_nth_time_block (1);
            assert_true (time_block.duration == template.short_break_duration);

            time_block = session.get_last_time_block ();
            assert_true (time_block.duration == template.long_break_duration);
        }

        public void test_get_first_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (session.get_first_time_block () == time_blocks[0]);

            var empty_session = new Pomodoro.Session ();
            assert_null (empty_session.get_first_time_block ());
        }

        public void test_get_last_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (session.get_last_time_block () == time_blocks[7]);

            var empty_session = new Pomodoro.Session ();
            assert_null (empty_session.get_last_time_block ());
        }

        public void test_get_next_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (
                session.get_next_time_block (time_blocks[0]) == time_blocks[1]
            );
            assert_true (
                session.get_next_time_block (time_blocks[1]) == time_blocks[2]
            );
            assert_null (
                session.get_next_time_block (time_blocks[7])
            );
            assert_null (
                session.get_next_time_block (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO))
            );
        }

        public void test_get_previous_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (
                session.get_previous_time_block (time_blocks[2]) == time_blocks[1]
            );
            assert_true (
                session.get_previous_time_block (time_blocks[1]) == time_blocks[0]
            );
            assert_null (
                session.get_previous_time_block (time_blocks[0])
            );
            assert_null (
                session.get_previous_time_block (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO))
            );
        }

        // public void test_calculate_pomodoro_break_ratio ()
        // {
        //     var session = new Pomodoro.Session ();
        //
        //     assert_cmpfloat_with_epsilon (
        //         session.calculate_pomodoro_break_ratio (),
        //         double.INFINITY,
        //         0.0001
        //     );
        // }

        /**
         * Check moving all time blocks to a given timestamp when none of the blocks have started.
         */
        public void test_reschedule__strict ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });
            var expected_session_start_time = Pomodoro.Timestamp.from_now () + Pomodoro.Interval.MINUTE;
            var expected_session_duration = session.duration;

            session.reschedule (this.session_template,
                                Pomodoro.Strictness.STRICT,
                                expected_session_start_time);

            assert_cmpuint (
                count_pomodoros (session),
                GLib.CompareOperator.EQ,
                this.session_template.cycles
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (expected_session_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.duration),
                new GLib.Variant.int64 (expected_session_duration)
            );
            assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        }


        /*
         * Tests for strict scheduling
         */

        // /**
        //  * Expect .reschedule() to remove unscheduled time-blocks.
        //  */
        // public void test_reschedule__strict__after_unscheduled_pomodoro ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);

        //     var first_pomodoro = session.get_first_time_block ();
        //     session.mark_time_block_ended (first_pomodoro, false, first_pomodoro.end_time);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = first_pomodoro.start_time + Pomodoro.Interval.MINUTE;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         first_pomodoro.start_time + Pomodoro.Interval.MINUTE);

        //     assert_false (session.contains (first_pomodoro));

            // There is no consensus how it should behave.

        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Expect .reschedule() to remove unscheduled time-blocks.
        //  */
        // public void test_reschedule__strict__after_unscheduled_short_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 1);

        //     var short_break = session.get_nth_time_block (1);
        //     session.mark_time_block_ended (short_break, false, short_break.end_time);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         short_break.start_time + Pomodoro.Interval.MINUTE);

        //     assert_false (session.contains (short_break));

        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Expect .reschedule() to remove unscheduled time-blocks.
        //  */
        // public void test_reschedule__strict__after_unscheduled_long_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 7);

        //     var first_long_break = session.get_last_time_block ();
        //     first_long_break.status = Pomodoro.TimeBlockStatus.UNSCHEDULED;

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         first_long_break.start_time + Pomodoro.Interval.MINUTE);

        //     assert_false (session.contains (first_long_break));

        //     var second_long_break = session.get_last_time_block ();
        //     assert_true (second_long_break.state == Pomodoro.State.BREAK);
        //     assert_true (second_long_break.status == Pomodoro.TimeBlockStatus.SCHEDULED);
        //     assert_true (session.is_time_block_long_break (second_long_break));

        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Expect .reschedule() to not to affect a in-progress time-block
        //  */
        // public void test_reschedule__strict__after_in_progress_pomodoro ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 2);

        //     var pomodoro = session.get_nth_time_block (2);
        //     pomodoro.status = Pomodoro.TimeBlockStatus.IN_PROGRESS;

        //     var short_break = session.get_next_time_block (pomodoro);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = session.start_time;
        //     var expected_pomodoro_end_time = pomodoro.end_time;
        //     var expected_short_break_start_time = short_break.start_time;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         pomodoro.start_time + Pomodoro.Interval.MINUTE);

        //     assert_true (pomodoro.state == Pomodoro.State.POMODORO);
        //     assert_true (short_break.state == Pomodoro.State.BREAK);

        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.end_time),
        //         new GLib.Variant.int64 (expected_pomodoro_end_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (short_break.start_time),
        //         new GLib.Variant.int64 (expected_short_break_start_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Expect .reschedule() to not to affect a in-progress time-block
        //  */
        // public void test_reschedule__strict__after_in_progress_short_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 1);

        //     var short_break = session.get_nth_time_block (1);
        //     short_break.status = Pomodoro.TimeBlockStatus.IN_PROGRESS;

        //     var pomodoro = session.get_next_time_block (short_break);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = session.start_time;
        //     var expected_short_break_end_time = short_break.end_time;
        //     var expected_pomodoro_start_time = short_break.end_time;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         short_break.start_time + Pomodoro.Interval.MINUTE);

        //     assert_true (short_break.state == Pomodoro.State.BREAK);
        //     assert_true (pomodoro.state == Pomodoro.State.POMODORO);

        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (short_break.end_time),
        //         new GLib.Variant.int64 (expected_short_break_end_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.start_time),
        //         new GLib.Variant.int64 (expected_pomodoro_start_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Last time-block is in progress. Expect .reschedule() to not to nothing.
        //  */
        // public void test_reschedule__strict__after_in_progress_long_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 7);

        //     var long_break = session.get_last_time_block ();
        //     long_break.status = Pomodoro.TimeBlockStatus.IN_PROGRESS;

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = session.start_time;
        //     var expected_long_break_end_time = long_break.end_time;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         long_break.start_time + Pomodoro.Interval.MINUTE);

        //     assert_true (long_break.state == Pomodoro.State.BREAK);

        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (long_break.end_time),
        //         new GLib.Variant.int64 (expected_long_break_end_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 0);
        // }

        // /**
        //  * Check moving only future time blocks to a given timestamp.
        //  */
        // public void test_reschedule__strict__after_completed_pomodoro ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);

        //     var pomodoro = session.get_first_time_block ();
        //     pomodoro.status = Pomodoro.TimeBlockStatus.COMPLETED;

        //     var short_break = session.get_next_time_block (pomodoro);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = pomodoro.start_time;
        //     var expected_pomodoro_end_time = pomodoro.end_time;
        //     var expected_short_break_start_time = pomodoro.end_time + Pomodoro.Interval.MINUTE;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         pomodoro.end_time + Pomodoro.Interval.MINUTE);
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.end_time),
        //         new GLib.Variant.int64 (expected_pomodoro_end_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (short_break.start_time),
        //         new GLib.Variant.int64 (expected_short_break_start_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Check moving only future time blocks to a given timestamp.
        //  */
        // public void test_reschedule__strict__after_completed_short_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 2);

        //     var short_break = session.get_nth_time_block (1);
        //     var pomodoro = session.get_next_time_block (short_break);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = session.start_time;
        //     var expected_pomodoro_start_time = pomodoro.end_time + Pomodoro.Interval.MINUTE;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         pomodoro.end_time + Pomodoro.Interval.MINUTE);
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.start_time),
        //         new GLib.Variant.int64 (expected_pomodoro_start_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * All blocks have been completed, expect .reschedule() to do nothing.
        //  */
        // public void test_reschedule__strict__after_completed_long_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 8);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = session.start_time;
        //     var expected_session_end_time = session.end_time;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         session.end_time + Pomodoro.Interval.MINUTE);
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.end_time),
        //         new GLib.Variant.int64 (expected_session_end_time)
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 0);
        // }

        // /**
        //  * Pomodoro hasn't been completed, expect extra cycle to be added.
        //  */
        // public void test_reschedule__strict__after_uncompleted_pomodoro ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);

        //     var pomodoro = session.get_first_time_block ();
        //     pomodoro.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_session_start_time = session.start_time;
        //     var expected_pomodoro_end_time = pomodoro.end_time;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         expected_pomodoro_end_time);
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (session.start_time),
        //         new GLib.Variant.int64 (expected_session_start_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.end_time),
        //         new GLib.Variant.int64 (expected_pomodoro_end_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles + 1
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // /**
        //  * Expect no penalty for skipping a short break.
        //  */
        // public void test_reschedule__strict__after_uncompleted_short_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 1);

        //     var short_break = session.get_nth_time_block (1);
        //     short_break.duration = Pomodoro.Interval.MINUTE;
        //     short_break.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;

        //     var pomodoro = session.get_next_time_block (short_break);

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });
        //     var expected_short_break_end_time = short_break.end_time;
        //     var expected_pomodoro_start_time = short_break.end_time + Pomodoro.Interval.MINUTE;

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         short_break.end_time + Pomodoro.Interval.MINUTE);
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (short_break.end_time),
        //         new GLib.Variant.int64 (expected_short_break_end_time)
        //     );
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.start_time),
        //         new GLib.Variant.int64 (expected_pomodoro_start_time)
        //     );
        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // public void test_reschedule__strict__after_uncompleted_long_break ()
        // {
        //     var session = new Pomodoro.Session.from_template (this.session_template);
        //     mark_time_blocks_completed (session, 7);

        //     var first_long_break = session.get_last_time_block ();
        //     first_long_break.duration = 3 * Pomodoro.Interval.MINUTE;
        //     first_long_break.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;

        //     var expected_pomodoro_start_time = first_long_break.end_time + Pomodoro.Interval.MINUTE;
        //     var expected_second_long_break_duration = this.session_template.long_break_duration;

        //     var changed_emitted = 0;
        //     session.changed.connect (() => {
        //         changed_emitted++;
        //     });

        //     session.reschedule (this.session_template,
        //                         Pomodoro.Strictness.STRICT,
        //                         first_long_break.end_time + Pomodoro.Interval.MINUTE);

        //     assert_true (first_long_break.state == Pomodoro.State.BREAK);
        //     assert_true (first_long_break.status == Pomodoro.TimeBlockStatus.UNCOMPLETED);
        //     assert_true (session.is_time_block_long_break (first_long_break));

        //     var pomodoro = session.get_next_time_block (first_long_break);
        //     assert_true (pomodoro.state == Pomodoro.State.POMODORO);
        //     assert_true (pomodoro.status == Pomodoro.TimeBlockStatus.SCHEDULED);
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (pomodoro.start_time),
        //         new GLib.Variant.int64 (expected_pomodoro_start_time)
        //     );

        //     var second_long_break = session.get_next_time_block (pomodoro);
        //     assert_true (second_long_break == session.get_last_time_block ());
        //     assert_true (second_long_break.state == Pomodoro.State.BREAK);
        //     assert_true (second_long_break.status == Pomodoro.TimeBlockStatus.SCHEDULED);
        //     assert_true (session.is_time_block_long_break (second_long_break));
        //     assert_cmpvariant (
        //         new GLib.Variant.int64 (second_long_break.duration),
        //         new GLib.Variant.int64 (expected_second_long_break_duration)
        //     );

        //     assert_cmpuint (
        //         count_pomodoros (session),
        //         GLib.CompareOperator.EQ,
        //         this.session_template.cycles + 1
        //     );
        //     assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
        // }

        // public void test_reschedule__strict__template_change ()
        // {
            // TODO
        // }



        public void test_reschedule__lenient ()
        {
            // TODO
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionTest ()
    );
}
