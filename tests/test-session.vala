namespace Tests
{
    public class SessionTemplateTest : Tests.TestSuite
    {
        public SessionTemplateTest ()
        {
            this.add_test ("calculate_break_ratio", this.test_calculate_break_ratio);
        }

        public void test_calculate_break_ratio ()
        {
            var session_template_1 = Pomodoro.SessionTemplate () {
                pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
                short_break_duration = 0 * Pomodoro.Interval.MINUTE,
                long_break_duration = 0 * Pomodoro.Interval.MINUTE,
                cycles = 4
            };
            assert_cmpfloat_with_epsilon (session_template_1.calculate_break_ratio (), 0.0, 0.0001);

            var session_template_2 = Pomodoro.SessionTemplate () {
                pomodoro_duration = 0 * Pomodoro.Interval.MINUTE,
                short_break_duration = 5 * Pomodoro.Interval.MINUTE,
                long_break_duration = 15 * Pomodoro.Interval.MINUTE,
                cycles = 4
            };
            assert_cmpfloat_with_epsilon (session_template_2.calculate_break_ratio (), 1.0, 0.0001);

            var session_template_3 = Pomodoro.SessionTemplate () {
                pomodoro_duration = 3 * Pomodoro.Interval.MINUTE,
                short_break_duration = 1 * Pomodoro.Interval.MINUTE,
                long_break_duration = 1 * Pomodoro.Interval.MINUTE,
                cycles = 1
            };
            // 1 / (3 + 1)
            assert_cmpfloat_with_epsilon (session_template_3.calculate_break_ratio (), 0.25, 0.0001);

            var session_template_4 = Pomodoro.SessionTemplate () {
                pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
                short_break_duration = 5 * Pomodoro.Interval.MINUTE,
                long_break_duration = 10 * Pomodoro.Interval.MINUTE,
                cycles = 4
            };
            // (5 + 5 + 5 + 10) / (25 + 5 + 25 + 5 + 25 + 5 + 25 + 10)
            assert_cmpfloat_with_epsilon (session_template_4.calculate_break_ratio (), 0.2, 0.0001);
        }
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

            this.add_test ("cycles", this.test_cycles);
            this.add_test ("duration", this.test_duration);
            this.add_test ("start_time", this.test_start_time);
            this.add_test ("end_time", this.test_end_time);

            this.add_test ("get_first_time_block", this.test_get_first_time_block);
            this.add_test ("get_last_time_block", this.test_get_last_time_block);
            this.add_test ("get_next_time_block", this.test_get_next_time_block);
            this.add_test ("get_previous_time_block", this.test_get_previous_time_block);
            this.add_test ("append", this.test_append);
            this.add_test ("prepend", this.test_prepend);
            this.add_test ("insert_before", this.test_insert_before);
            this.add_test ("insert_after", this.test_insert_after);
            this.add_test ("contains", this.test_contains);
            this.add_test ("move_by", this.test_move_by);
            this.add_test ("move_to", this.test_move_to);

            this.add_test ("get_time_block_meta", this.test_get_time_block_meta);
            this.add_test ("mark_time_block_completed", this.test_mark_time_block_completed);
            this.add_test ("mark_time_block_uncompleted", this.test_mark_time_block_uncompleted);
            this.add_test ("is_expired", this.test_is_expired);
            this.add_test ("calculate_elapsed", this.test_calculate_elapsed);
            this.add_test ("calculate_remaining", this.test_calculate_remaining);
            // this.add_test ("calculate_progress", this.test_calculate_progress);
            this.add_test ("calculate_energy", this.test_calculate_energy);
            // this.add_test ("calculate_pomodoro_break_ratio", this.test_calculate_pomodoro_break_ratio);
            this.add_test ("calculate_break_ratio", this.test_calculate_break_ratio);

            // TODO: Tests for signals
            // this.add_test ("freeze_changed", this.test_freeze_changed);
            // this.add_test ("changed_signal", this.test_changed_signal);
            // this.add_test ("added_signal", this.test_time_block_added_signal);
            // this.add_test ("removed_signal", this.test_time_block_removed_signal);
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

        /**
         * Check constructor `Session()`.
         *
         * Expect session not to have any time-blocks.
         */
        public void test_new ()
        {
            var session = new Pomodoro.Session ();

            var first_time_block = session.get_first_time_block ();
            assert_null (first_time_block);

            var last_time_block = session.get_last_time_block ();
            assert_null (last_time_block);

            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpuint (session.cycles, GLib.CompareOperator.EQ, 0);
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
            Pomodoro.TimeBlock[] time_blocks = {};

            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_cmpuint (time_blocks.length, GLib.CompareOperator.EQ, template.cycles * 2);

            // Expect:
            //   - pomodoro / break states to be interleaved
            //   - last break to be a long one
            //   - start times to align
            //   - `cycle` to be indexed form 1
            var expected_start_time = now;

            for (uint index=0; index < time_blocks.length; index++)
            {
                var time_block = time_blocks[index];
                var meta = session.get_time_block_meta (time_block);

                // GLib.info ("TimeBlock #%u", index);
                // GLib.info ("  state: %s", time_block.state.to_string ());
                // GLib.info ("  start_time: %lld", time_block.start_time);
                // GLib.info ("  duration: %lld", time_block.duration);
                // GLib.info ("  meta.intended_duration: %lld", meta.intended_duration);
                // GLib.info ("  meta.is_long_break: %s", meta.is_long_break ? "true" : "false");
                // GLib.info ("  meta.cycle: %u", meta.cycle);
                // GLib.info ("");

                if ((index & 1) == 0) {
                    assert_true (time_block.state == Pomodoro.State.POMODORO);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (meta.intended_duration),
                        new GLib.Variant.int64 (template.pomodoro_duration)
                    );
                    assert_false (meta.is_long_break);
                }
                else if (index < time_blocks.length - 1) {
                    assert_true (time_block.state == Pomodoro.State.BREAK);
                    assert_false (meta.is_long_break);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (meta.intended_duration),
                        new GLib.Variant.int64 (template.short_break_duration)
                    );
                }
                else {
                    assert_true (time_block.state == Pomodoro.State.BREAK);
                    assert_true (meta.is_long_break);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (meta.intended_duration),
                        new GLib.Variant.int64 (template.long_break_duration)
                    );
                }

                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block.start_time),
                    new GLib.Variant.int64 (expected_start_time)
                );
                assert_true (time_block.session == session);
                assert_cmpuint (meta.cycle, GLib.CompareOperator.EQ, 1 + (index >> 1));

                expected_start_time += meta.intended_duration;
            }

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
            assert_cmpuint (session.cycles, GLib.CompareOperator.EQ, template.cycles);
        }

        public void test_cycles ()
        {
            var notify_cycles_emitted = 0;

            var session_0 = new Pomodoro.Session ();
            assert_cmpuint (session_0.cycles, GLib.CompareOperator.EQ, 0);

            var session_1 = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    cycles = 1
                }
            );
            assert_cmpuint (session_1.cycles, GLib.CompareOperator.EQ, 1);

            var session_2 = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    cycles = 2
                }
            );
            assert_cmpuint (session_2.cycles, GLib.CompareOperator.EQ, 2);

            // When session starts with a break, expect cycles to be 0.
            var session_3 = new Pomodoro.Session ();
            session_3.notify["cycles"].connect (() => {
                notify_cycles_emitted++;
            });
            session_3.append (new Pomodoro.TimeBlock (Pomodoro.State.BREAK));
            assert_cmpuint (session_3.cycles, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 0);
            session_3.append (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO));
            assert_cmpuint (session_3.cycles, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 1);
            notify_cycles_emitted = 0;

            // When pomodoros are after one another, expect cycle to increment; though it's not a true cycle.
            // In normal case pomodoro would be extended and counted properly.
            var session_4 = new Pomodoro.Session ();
            session_4.notify["cycles"].connect (() => {
                notify_cycles_emitted++;
            });
            session_4.append (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO));
            assert_cmpuint (session_4.cycles, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 1);
            session_4.append (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO));
            assert_cmpuint (session_4.cycles, GLib.CompareOperator.EQ, 2);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 2);
            notify_cycles_emitted = 0;

            // Treat undefined states same as breaks.
            var session_5 = new Pomodoro.Session ();
            session_5.append (new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED));
            assert_cmpuint (session_5.cycles, GLib.CompareOperator.EQ, 0);
            session_5.append (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO));
            assert_cmpuint (session_5.cycles, GLib.CompareOperator.EQ, 1);

            // Don't count time-blocks marked as uncompleted.
            var session_6 = new Pomodoro.Session ();
            session_6.notify["cycles"].connect (() => {
                notify_cycles_emitted++;
            });
            var uncompleted_time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            session_6.append (uncompleted_time_block);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 1);
            session_6.mark_time_block_uncompleted (uncompleted_time_block);
            assert_cmpuint (session_6.cycles, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 2);
            session_6.append (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO));
            assert_cmpuint (session_6.cycles, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (notify_cycles_emitted, GLib.CompareOperator.EQ, 3);
        }

        public void test_duration ()
        {
            var notify_duration_emitted = 0;
            var now = Pomodoro.Timestamp.advance (0);

            var session_0 = new Pomodoro.Session ();
            assert_cmpvariant (
                new GLib.Variant.int64 (session_0.duration),
                new GLib.Variant.int64 (0)
            );

            var session_1 = new Pomodoro.Session ();
            session_1.notify["duration"].connect (() => {
                notify_duration_emitted++;
            });

            var time_block_1 = new Pomodoro.TimeBlock ();
            time_block_1.set_time_range (now, now + 2 * Pomodoro.Interval.MINUTE);
            session_1.append (time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.duration),
                new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (notify_duration_emitted, GLib.CompareOperator.EQ, 1);

            var time_block_2 = new Pomodoro.TimeBlock ();
            time_block_2.set_time_range (now, now + 3 * Pomodoro.Interval.MINUTE);
            session_1.append (time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.duration),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (notify_duration_emitted, GLib.CompareOperator.EQ, 2);

            // Adding a gap between time-blocks should increase duration.
            time_block_2.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.duration),
                new GLib.Variant.int64 (6 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (notify_duration_emitted, GLib.CompareOperator.EQ, 3);

            // Moving a session shouldn't emit notify signal.
            session_1.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.duration),
                new GLib.Variant.int64 (6 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (notify_duration_emitted, GLib.CompareOperator.EQ, 3);

            // Uncompleted time-blocks should be included in duration.
            session_1.mark_time_block_uncompleted (time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.duration),
                new GLib.Variant.int64 (6 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (notify_duration_emitted, GLib.CompareOperator.EQ, 3);
        }

        public void test_start_time ()
        {
            var notify_start_time_emitted = 0;
            var now = Pomodoro.Timestamp.advance (0);

            var session_0 = new Pomodoro.Session ();
            assert_cmpvariant (
                new GLib.Variant.int64 (session_0.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );

            var session_1 = new Pomodoro.Session ();
            session_1.notify["start-time"].connect (() => {
                notify_start_time_emitted++;
            });

            var time_block_2 = new Pomodoro.TimeBlock ();
            time_block_2.set_time_range (now + 4 * Pomodoro.Interval.MINUTE,
                                         now + 5 * Pomodoro.Interval.MINUTE);
            session_1.prepend (time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.start_time),
                new GLib.Variant.int64 (time_block_2.start_time)
            );
            assert_cmpuint (notify_start_time_emitted, GLib.CompareOperator.EQ, 1);

            var time_block_1 = new Pomodoro.TimeBlock ();
            time_block_1.set_time_range (now + 3 * Pomodoro.Interval.MINUTE,
                                         now + 4 * Pomodoro.Interval.MINUTE);
            session_1.prepend (time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.start_time),
                new GLib.Variant.int64 (time_block_1.start_time)
            );
            assert_cmpuint (notify_start_time_emitted, GLib.CompareOperator.EQ, 2);

            // Moving first time-block should affect start_time.
            var expected_start_time = time_block_1.start_time + Pomodoro.Interval.MINUTE;
            time_block_1.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpuint (notify_start_time_emitted, GLib.CompareOperator.EQ, 3);

            // Moving a session should emit notify signal.
            expected_start_time = session_1.start_time + Pomodoro.Interval.MINUTE;
            session_1.move_to (expected_start_time);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpuint (notify_start_time_emitted, GLib.CompareOperator.EQ, 4);

            // Moving second time-block should not affect start_time.
            expected_start_time = session_1.start_time;
            time_block_2.move_to (time_block_2.start_time + Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpuint (notify_start_time_emitted, GLib.CompareOperator.EQ, 4);

            // Uncompleted time-blocks should be included in start_time.
            expected_start_time = session_1.start_time;
            session_1.mark_time_block_uncompleted (time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpuint (notify_start_time_emitted, GLib.CompareOperator.EQ, 4);
        }

        public void test_end_time ()
        {
            var notify_end_time_emitted = 0;
            var now = Pomodoro.Timestamp.advance (0);

            var session_0 = new Pomodoro.Session ();
            assert_cmpvariant (
                new GLib.Variant.int64 (session_0.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );

            var session_1 = new Pomodoro.Session ();
            session_1.notify["end-time"].connect (() => {
                notify_end_time_emitted++;
            });

            var time_block_1 = new Pomodoro.TimeBlock ();
            time_block_1.set_time_range (now + 3 * Pomodoro.Interval.MINUTE,
                                         now + 4 * Pomodoro.Interval.MINUTE);
            session_1.append (time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.end_time),
                new GLib.Variant.int64 (time_block_1.end_time)
            );
            assert_cmpuint (notify_end_time_emitted, GLib.CompareOperator.EQ, 1);

            var time_block_2 = new Pomodoro.TimeBlock ();
            time_block_2.set_time_range (now + 4 * Pomodoro.Interval.MINUTE,
                                         now + 5 * Pomodoro.Interval.MINUTE);
            session_1.append (time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.end_time),
                new GLib.Variant.int64 (time_block_2.end_time)
            );
            assert_cmpuint (notify_end_time_emitted, GLib.CompareOperator.EQ, 2);

            // Moving second time-block should affect end_time.
            var expected_end_time = time_block_2.end_time + Pomodoro.Interval.MINUTE;
            time_block_2.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.end_time),
                new GLib.Variant.int64 (expected_end_time)
            );
            assert_cmpuint (notify_end_time_emitted, GLib.CompareOperator.EQ, 3);

            // Moving a session should emit notify signal.
            expected_end_time = session_1.end_time + Pomodoro.Interval.MINUTE;
            session_1.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.end_time),
                new GLib.Variant.int64 (expected_end_time)
            );
            assert_cmpuint (notify_end_time_emitted, GLib.CompareOperator.EQ, 4);

            // Moving first time-block should not affect end_time.
            expected_end_time = session_1.end_time;
            time_block_1.move_by (-Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.end_time),
                new GLib.Variant.int64 (expected_end_time)
            );
            assert_cmpuint (notify_end_time_emitted, GLib.CompareOperator.EQ, 4);

            // Uncompleted time-blocks should be included in end_time.
            expected_end_time = session_1.end_time;
            session_1.mark_time_block_uncompleted (time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_1.end_time),
                new GLib.Variant.int64 (expected_end_time)
            );
            assert_cmpuint (notify_end_time_emitted, GLib.CompareOperator.EQ, 4);
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

        public void test_append ()
        {
            var session = new Pomodoro.Session ();
            var now     = Pomodoro.Timestamp.from_now ();

            var added_emitted = 0;
            session.added.connect (() => {
                added_emitted++;
            });

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });

            var time_block_1 = new Pomodoro.TimeBlock ();
            time_block_1.set_time_range (now, now + Pomodoro.Interval.MINUTE);
            session.append (time_block_1);
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_true (session.get_last_time_block () == time_block_1);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.start_time),
                new GLib.Variant.int64 (now)
            );

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.set_time_range (now, now + Pomodoro.Interval.MINUTE);
            session.append (time_block_2);
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);
            assert_true (session.get_last_time_block () == time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (time_block_1.end_time)
            );
        }

        public void test_prepend ()
        {
            var session = new Pomodoro.Session ();

            var added_emitted = 0;
            session.added.connect (() => {
                added_emitted++;
            });

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });

            var time_block_1 = new Pomodoro.TimeBlock ();
            session.prepend (time_block_1);
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_true (session.get_first_time_block () == time_block_1);

            var time_block_2 = new Pomodoro.TimeBlock ();
            session.prepend (time_block_2);
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);
            assert_true (session.get_first_time_block () == time_block_2);
        }

        public void test_insert_before ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);

            var added_emitted = 0;
            session.added.connect (() => {
                added_emitted++;
            });

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });

            var reference_time_block = session.get_last_time_block ();

            var time_block_1 = new Pomodoro.TimeBlock ();
            session.insert_before (time_block_1, reference_time_block);
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_true (session.get_previous_time_block (reference_time_block) == time_block_1);

            var time_block_2 = new Pomodoro.TimeBlock ();
            session.insert_before (time_block_2, session.get_first_time_block ());
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);
            assert_true (session.get_first_time_block () == time_block_2);
        }

        public void test_insert_after ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);

            var added_emitted = 0;
            session.added.connect (() => {
                added_emitted++;
            });

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });

            var reference_time_block = session.get_last_time_block ();

            var time_block_1 = new Pomodoro.TimeBlock ();
            session.insert_after (time_block_1, reference_time_block);
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_true (session.get_next_time_block (reference_time_block) == time_block_1);

            var time_block_2 = new Pomodoro.TimeBlock ();
            session.insert_after (time_block_2, session.get_last_time_block ());
            assert_cmpuint (added_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 2);
            assert_true (session.get_last_time_block () == time_block_2);
        }

        public void test_contains ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block = new Pomodoro.TimeBlock ();

            assert_false (session.contains (time_block));

            session.append (time_block);
            assert_true (session.contains (time_block));
        }

        public void test_move_by ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var first_time_block = session.get_first_time_block ();

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });

            var expected_start_time = session.start_time + Pomodoro.Interval.MINUTE;
            session.move_by (Pomodoro.Interval.MINUTE);
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (first_time_block.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_move_to ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var first_time_block = session.get_first_time_block ();

            var changed_emitted = 0;
            session.changed.connect (() => {
                changed_emitted++;
            });

            var expected_start_time = session.start_time + Pomodoro.Interval.MINUTE;
            session.move_to (expected_start_time);
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (first_time_block.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_cmpuint (changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_get_time_block_meta ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);

            var first_time_block = session.get_first_time_block ();
            var first_time_block_meta = session.get_time_block_meta (first_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (first_time_block_meta.intended_duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            assert_cmpuint (first_time_block_meta.cycle, GLib.CompareOperator.EQ, 1);
            assert_false (first_time_block_meta.is_long_break);
            assert_false (first_time_block_meta.is_completed);
            assert_false (first_time_block_meta.is_uncompleted);

            var last_time_block = session.get_last_time_block ();
            var last_time_block_meta = session.get_time_block_meta (last_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (last_time_block_meta.intended_duration),
                new GLib.Variant.int64 (this.session_template.long_break_duration)
            );
            assert_cmpuint (last_time_block_meta.cycle, GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_true (last_time_block_meta.is_long_break);
            assert_false (last_time_block_meta.is_completed);
            assert_false (last_time_block_meta.is_uncompleted);
        }

        public void test_mark_time_block_completed ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);

            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);

            session.mark_time_block_completed (time_block_1);
            assert_true (session.get_time_block_meta (time_block_1).is_completed);
            assert_false (session.get_time_block_meta (time_block_2).is_completed);

            session.mark_time_block_completed (time_block_3);
            assert_true (session.get_time_block_meta (time_block_3).is_completed);
            assert_false (session.get_time_block_meta (time_block_2).is_completed);
            assert_true (session.get_time_block_meta (time_block_2).is_uncompleted);

            session.mark_time_block_uncompleted (time_block_2);
            assert_false (session.get_time_block_meta (time_block_2).is_completed);
            assert_true (session.get_time_block_meta (time_block_2).is_uncompleted);
            assert_true (session.get_time_block_meta (time_block_1).is_completed);
        }

        public void test_mark_time_block_uncompleted ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);

            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);

            session.mark_time_block_uncompleted (time_block_1);
            assert_true (session.get_time_block_meta (time_block_1).is_uncompleted);
            assert_false (session.get_time_block_meta (time_block_2).is_uncompleted);

            session.mark_time_block_uncompleted (time_block_3);
            assert_true (session.get_time_block_meta (time_block_3).is_uncompleted);
            assert_false (session.get_time_block_meta (time_block_3).is_completed);
            assert_true (session.get_time_block_meta (time_block_2).is_uncompleted);

            session.mark_time_block_completed (time_block_2);
            assert_true (session.get_time_block_meta (time_block_2).is_completed);
            assert_false (session.get_time_block_meta (time_block_2).is_uncompleted);
            assert_true (session.get_time_block_meta (time_block_1).is_uncompleted);
        }

        public void test_is_expired ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var session = new Pomodoro.Session.from_template (this.session_template);
            assert_false (session.is_expired (now));

            session.set_expiry_time (now + Pomodoro.Interval.MINUTE);
            assert_false (session.is_expired (now));
            assert_true (session.is_expired (now + Pomodoro.Interval.MINUTE));
        }

        public void test_calculate_elapsed ()
        {
            // TODO
        }

        public void test_calculate_remaining ()
        {
            // TODO
        }

        // public void test_calculate_progress ()
        // {
        // }

        public void test_calculate_energy ()
        {
            // TODO
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

        public void test_calculate_break_ratio ()
        {
            var session = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
                    short_break_duration = 5 * Pomodoro.Interval.MINUTE,
                    long_break_duration = 10 * Pomodoro.Interval.MINUTE,
                    cycles = 2
                }
            );
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);
            var time_block_4 = session.get_nth_time_block (3);

            assert_cmpfloat_with_epsilon (session.calculate_break_ratio (time_block_1.end_time),
                                          0.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (session.calculate_break_ratio (time_block_2.end_time),
                                          5.0 / 30.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (session.calculate_break_ratio (time_block_3.end_time),
                                          5.0 / 55.0,
                                          0.0001);
            assert_cmpfloat_with_epsilon (session.calculate_break_ratio (time_block_4.end_time),
                                          15.0 / 65.0,
                                          0.0001);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionTemplateTest (),
        new Tests.SessionTest ()
    );
}
