namespace Tests
{
    public void foreach_state (GLib.Func<Pomodoro.State> func)
    {
        Pomodoro.State[] states = {
            Pomodoro.State.UNDEFINED,
            Pomodoro.State.POMODORO,
            Pomodoro.State.BREAK
        };

        foreach (var state in states)
        {
            func (state);
        }
    }


    public abstract class BaseSchedulerTest : Tests.TestSuite
    {
        protected Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        // public BaseSchedulerTest ()
        // {
            // this.add_test ("new", this.test_new);
            // this.add_test ("new_from_template", this.test_new_from_template);
        // }

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
    }

    public class StrictSchedulerTest : BaseSchedulerTest
    {
        public StrictSchedulerTest ()
        {
            this.add_test ("calculate_cycles_completed", this.test_calculate_cycles_completed);

            this.add_test ("is_time_block_completed__pomodoro", this.test_is_time_block_completed__pomodoro);
            this.add_test ("is_time_block_completed__short_break", this.test_is_time_block_completed__short_break);
            this.add_test ("is_time_block_completed__long_break", this.test_is_time_block_completed__long_break);

            // this.add_test ("is_long_break_needed", this.test_is_long_break_needed);

            this.add_test ("resolve_context__copy_state", this.test_resolve_context__copy_state);
            this.add_test ("resolve_context__increment_cycle", this.test_resolve_context__increment_cycle);
            this.add_test ("resolve_context__increment_several_cycles", this.test_resolve_context__increment_several_cycles);
            this.add_test ("resolve_context__is_cycle_completed", this.test_resolve_context__is_cycle_completed);
            this.add_test ("resolve_context__is_session_completed", this.test_resolve_context__is_session_completed);

            this.add_test ("resolve_time_block__completed_session", this.test_resolve_time_block__completed_session);
            this.add_test ("resolve_time_block__extra_cycles", this.test_resolve_time_block__extra_cycles);
            this.add_test ("resolve_time_block__pomodoro", this.test_resolve_time_block__pomodoro);
            this.add_test ("resolve_time_block__short_break", this.test_resolve_time_block__short_break);
            this.add_test ("resolve_time_block__long_break", this.test_resolve_time_block__long_break);

            this.add_test ("reschedule__populate", this.test_reschedule__populate);
            this.add_test ("reschedule__pomodoro", this.test_reschedule__pomodoro);
            this.add_test ("reschedule__short_break", this.test_reschedule__short_break);
            this.add_test ("reschedule__long_break", this.test_reschedule__long_break);
            this.add_test ("reschedule__completed", this.test_reschedule__completed);
        }

        public void test_calculate_cycles_completed ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            var time_block_1 = new Pomodoro.TimeBlock ();
            time_block_1.set_time_range (now, now + 2 * Pomodoro.Interval.MINUTE);
            var time_block_1_meta = Pomodoro.TimeBlockMeta () {
                intended_duration = 5 * Pomodoro.Interval.MINUTE
            };
            var cycles_1 = scheduler.calculate_cycles_completed (time_block_1,
                                                                 time_block_1_meta,
                                                                 time_block_1.end_time);
            assert_cmpuint (cycles_1, GLib.CompareOperator.EQ, 0);

            var time_block_2 = new Pomodoro.TimeBlock ();
            time_block_2.set_time_range (now, now + 3 * Pomodoro.Interval.MINUTE);
            var time_block_2_meta = Pomodoro.TimeBlockMeta () {
                intended_duration = 5 * Pomodoro.Interval.MINUTE
            };
            var cycles_2 = scheduler.calculate_cycles_completed (time_block_2,
                                                                 time_block_2_meta,
                                                                 time_block_2.end_time);
            assert_cmpuint (cycles_2, GLib.CompareOperator.EQ, 1);

            var time_block_3 = new Pomodoro.TimeBlock ();
            time_block_3.set_time_range (now, now + 7 * Pomodoro.Interval.MINUTE);
            var time_block_3_meta = Pomodoro.TimeBlockMeta () {
                intended_duration = 5 * Pomodoro.Interval.MINUTE
            };
            var cycles_3 = scheduler.calculate_cycles_completed (time_block_3,
                                                                 time_block_3_meta,
                                                                 time_block_3.end_time);
            assert_cmpuint (cycles_3, GLib.CompareOperator.EQ, 1);

            var time_block_4 = new Pomodoro.TimeBlock ();
            time_block_4.set_time_range (now, now + 8 * Pomodoro.Interval.MINUTE);
            var time_block_4_meta = Pomodoro.TimeBlockMeta () {
                intended_duration = 5 * Pomodoro.Interval.MINUTE
            };
            var cycles_4 = scheduler.calculate_cycles_completed (time_block_4,
                                                                 time_block_4_meta,
                                                                 time_block_4.end_time);
            assert_cmpuint (cycles_4, GLib.CompareOperator.EQ, 2);
        }


        /**
         * Time-block should complete at least 50% of intended duration, and not be shorter than 1 minute.
         */
        // public void test_is_time_block_completed__undefined ()
        // {
        //     var now = Pomodoro.Timestamp.advance (0);
        //     var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

        //     var time_block = new Pomodoro.TimeBlock ();
        //     time_block.set_time_range (now, now + Pomodoro.Interval.MINUTE);

        //     var time_block_meta = Pomodoro.TimeBlockMeta ();
        //     assert_false (
        //         scheduler.is_time_block_completed (time_block,
        //                                            time_block_meta,
        //                                            time_block.end_time)
        //     );
        // }

        public void test_is_time_block_completed__pomodoro ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            var time_block = session.get_nth_time_block (2);
            var time_block_meta = session.get_time_block_meta (time_block);
            Pomodoro.Timestamp.freeze_to (time_block.start_time);
            assert_false (
                scheduler.is_time_block_completed (time_block,
                                                   time_block_meta,
                                                   time_block.start_time + 12 * Pomodoro.Interval.MINUTE)
            );
            assert_true (
                scheduler.is_time_block_completed (time_block,
                                                   time_block_meta,
                                                   time_block.start_time + 13 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_is_time_block_completed__short_break ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            var time_block = session.get_nth_time_block (3);
            var time_block_meta = session.get_time_block_meta (time_block);
            Pomodoro.Timestamp.freeze_to (time_block.start_time);
            assert_false (
                scheduler.is_time_block_completed (time_block,
                                                   time_block_meta,
                                                   time_block.start_time + 2 * Pomodoro.Interval.MINUTE)
            );
            assert_true (
                scheduler.is_time_block_completed (time_block,
                                                   time_block_meta,
                                                   time_block.start_time + 3 * Pomodoro.Interval.MINUTE)
            );
        }

        public void test_is_time_block_completed__long_break ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            var time_block = session.get_last_time_block ();
            var time_block_meta = session.get_time_block_meta (time_block);
            Pomodoro.Timestamp.freeze_to (time_block.start_time);
            assert_false (
                scheduler.is_time_block_completed (time_block,
                                                   time_block_meta,
                                                   time_block.start_time + 7 * Pomodoro.Interval.MINUTE)
            );
            assert_true (
                scheduler.is_time_block_completed (time_block,
                                                   time_block_meta,
                                                   time_block.start_time + 8 * Pomodoro.Interval.MINUTE)
            );
        }

        /*
        public void test_is_long_break_needed ()
        {
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            assert_false (
                scheduler.is_long_break_needed (
                    Pomodoro.SchedulerContext () {
                        cycle = scheduler.session_template.cycles - 1,
                        is_cycle_completed = true
                    }
                )
            );
            assert_false (
                scheduler.is_long_break_needed (
                    Pomodoro.SchedulerContext () {
                        cycle = scheduler.session_template.cycles,
                        is_cycle_completed = false
                    }
                )
            );
            assert_true (
                scheduler.is_long_break_needed (
                    Pomodoro.SchedulerContext () {
                        cycle = scheduler.session_template.cycles,
                        is_cycle_completed = true
                    }
                )
            );
        }
        */


        /**
         *
         */
        public void test_resolve_context__copy_state ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            foreach_state (
                (state) => {
                    var context = Pomodoro.SchedulerContext.initial ();
                    var time_block = new Pomodoro.TimeBlock (state);
                    time_block.set_time_range (now, now + Pomodoro.Interval.MINUTE);

                    var time_block_meta = Pomodoro.TimeBlockMeta ();
                    scheduler.resolve_context (time_block, time_block_meta, ref context);

                    // var expected_context = Pomodoro.SchedulerContext () {
                    //     timestamp = time_block.end_time,
                    //     state = state,
                    // };
                    assert_true (context.state == state);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (context.timestamp),
                        new GLib.Variant.int64 (time_block.end_time)
                    );
                }
            );
        }

        public void test_resolve_context__increment_cycle ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext ();

            // Mark `is_cycle_completed=true` for any time-block when `cycle` is 0.
            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            var time_block_1_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true
            };
            var expected_context_1 = Pomodoro.SchedulerContext () {
                cycle = 0,
                is_cycle_completed = true  // debatable
            };
            scheduler.resolve_context (time_block_1, time_block_1_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_1.to_variant ()
            );

            // Don't increment `cycle` for break, despite `is_cycle_completed`
            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_2_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true,
            };
            var expected_context_2 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.BREAK,
                cycle = 0,
                is_cycle_completed = true
            };
            scheduler.resolve_context (time_block_2, time_block_2_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_2.to_variant ()
            );

            // Increment `cycle` for pomodoro
            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_3_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false
            };
            var expected_context_3 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                is_cycle_completed = false
            };
            scheduler.resolve_context (time_block_3, time_block_3_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_3.to_variant ()
            );

            // Mark `is_cycle_completed` for a completed pomodoro
            var time_block_4 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_4_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true
            };
            var expected_context_4 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                is_cycle_completed = true,
            };
            scheduler.resolve_context (time_block_4, time_block_4_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_4.to_variant ()
            );
        }

        public void test_resolve_context__increment_several_cycles ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                cycle = 0,
                is_cycle_completed = true,
            };

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.set_time_range (now, now + 30 * Pomodoro.Interval.MINUTE);
            var time_block_meta = Pomodoro.TimeBlockMeta () {
                intended_duration = 20 * Pomodoro.Interval.MINUTE,
                is_completed = true,
            };
            var expected_context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 2,
                is_cycle_completed = true,
            };
            scheduler.resolve_context (time_block, time_block_meta, ref context);
        }

        public void test_resolve_context__is_cycle_completed ()
        {
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext ();

            // Start a session with a break. Expect cycle to remain 0 and uncompleted.
            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_1_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true,
                is_uncompleted = false
            };
            var expected_context_1 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.BREAK,
                cycle = 0,
                is_cycle_completed = true  // debatable
            };
            scheduler.resolve_context (time_block_1, time_block_1_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_1.to_variant ()
            );

            // Start a pomodoro. Expect cycle counter to increment.
            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_2_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false,
                is_uncompleted = false
            };
            var expected_context_2 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                is_cycle_completed = false
            };
            scheduler.resolve_context (time_block_2, time_block_2_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_2.to_variant ()
            );

            // Start another pomodoro while the cycle hasn't been completed. Expect cycle counter not to increment.
            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_3_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false,
                is_uncompleted = false
            };
            var expected_context_3 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                is_cycle_completed = false
            };
            scheduler.resolve_context (time_block_3, time_block_3_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_3.to_variant ()
            );

            // Pomodoro hasn't been completed. Expect cycle to stay uncompleted.
            var time_block_4 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_4_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false,
                is_uncompleted = true
            };
            var expected_context_4 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                is_cycle_completed = false
            };
            scheduler.resolve_context (time_block_4, time_block_4_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_4.to_variant ()
            );

            // Complete a Pomodoro. Expect cycle to be marked as completed.
            var time_block_5 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_5_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true,
                is_uncompleted = false
            };
            var expected_context_5 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                is_cycle_completed = true
            };
            scheduler.resolve_context (time_block_5, time_block_5_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_5.to_variant ()
            );

            // Complete a break. Expect cycle counter to stay the same.
            var time_block_6 = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_6_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true,
                is_uncompleted = false
            };
            var expected_context_6 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.BREAK,
                cycle = 1,
                is_cycle_completed = true
            };
            scheduler.resolve_context (time_block_6, time_block_6_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_6.to_variant ()
            );

            // Start a pomodoro. Expect cycle counter to increment.
            var time_block_7 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_7_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false,
                is_uncompleted = false
            };
            var expected_context_7 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 2,
                is_cycle_completed = false
            };
            scheduler.resolve_context (time_block_7, time_block_7_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_7.to_variant ()
            );
        }

        public void test_resolve_context__is_session_completed ()
        {
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = this.session_template.cycles,
                is_cycle_completed = false
            };

            // Completing last pomodoro should mark cycle as completed, but not the session.
            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_1_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true,
                is_uncompleted = false
            };
            var expected_context_1 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = this.session_template.cycles,
                is_cycle_completed = true,
                is_session_completed = false
            };
            scheduler.resolve_context (time_block_1, time_block_1_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_1.to_variant ()
            );

            // Only a completed long_break can mark session as completed.
            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_2_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false,
                is_uncompleted = false,
                is_long_break = true
            };
            var expected_context_2 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.BREAK,
                cycle = this.session_template.cycles,
                is_cycle_completed = true,
                is_session_completed = false
            };
            scheduler.resolve_context (time_block_2, time_block_2_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_2.to_variant ()
            );

            var time_block_3 = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_3_meta = Pomodoro.TimeBlockMeta () {
                is_completed = true,
                is_uncompleted = false,
                is_long_break = true
            };
            var expected_context_3 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.BREAK,
                cycle = this.session_template.cycles,
                is_cycle_completed = true,
                is_session_completed = true
            };
            scheduler.resolve_context (time_block_3, time_block_3_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_3.to_variant ()
            );

            // Expect to continue counting cycles for this session despite `is_session_completed`.
            // `SessionManager` should start a new session. Scheduler will be resolving context from scratch.
            var time_block_4 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_4_meta = Pomodoro.TimeBlockMeta () {
                is_completed = false,
                is_uncompleted = false
            };
            var expected_context_4 = Pomodoro.SchedulerContext () {
                state = Pomodoro.State.POMODORO,
                cycle = 5,
                is_session_completed = true
            };
            scheduler.resolve_context (time_block_4, time_block_4_meta, ref context);
            assert_cmpvariant (
                context.to_variant (),
                expected_context_4.to_variant ()
            );
        }


        /**
         * Expect .resolve_context() with completed pomodoro to increment cycle count.
         */
        public void test_resolve_context__completed_pomodoro ()
        {
            // var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext.initial ();

            // var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            // var time_block_1_meta = Pomodoro.TimeBlockMeta () {
            //     cycle = 1,
            //     intended_duration = time_block.duration,
            //     is_session_completed = true
            // };
            // scheduler.resolve_context (time_block_1, time_block_1_meta, ref context);

            // var expected_context = Pomodoro.SchedulerContext () {
            //     timestamp = time_block.end_time,
            //     state = Pomodoro.State.POMODORO,
            //     cycle = 2,
            //     needs_long_break = false,
            //     is_session_completed = false
            // };
            // assert_cmpvariant (
            //     context.to_variant (),
            //     expected_context.to_variant ()
            // );
        }

        /**
         * Expect .resolve_context() with uncompleted pomodoro not to increment cycle count.
         */
        public void test_resolve_context__uncompleted_pomodoro ()
        {
            // var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext.initial ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            var time_block_meta = Pomodoro.TimeBlockMeta () {
                cycle = 1,
                intended_duration = time_block.duration,
                is_uncompleted = true
            };
            scheduler.resolve_context (time_block, time_block_meta, ref context);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.POMODORO,
                cycle = 1,
                // needs_long_break = false,
                is_session_completed = false
            };
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        /**
         * Expect .resolve_context() with completed short-break not to change anything except timestamp.
         */
        public void test_resolve_context__completed_short_break ()
        {
            // var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext.initial ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_meta = Pomodoro.TimeBlockMeta () {
                cycle = 1,
                intended_duration = time_block.duration,
                is_completed = true
            };
            scheduler.resolve_context (time_block, time_block_meta, ref context);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.BREAK,
                cycle = 1,
                // needs_long_break = false,
                is_session_completed = false
            };
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        /**
         * Expect .resolve_context() with uncompleted short-break not to change anything except timestamp.
         */
        public void test_resolve_context__uncompleted_short_break ()
        {
            // var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext.initial ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_meta = Pomodoro.TimeBlockMeta () {
                cycle = 1,
                intended_duration = time_block.duration,
                is_uncompleted = true
            };
            scheduler.resolve_context (time_block, time_block_meta, ref context);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.BREAK,
                cycle = 1,
                // needs_long_break = false,
                is_session_completed = false
            };
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        /**
         * Expect .resolve_context() with completed long-break to indicate that session has completed.
         */
        public void test_resolve_context__completed_long_break ()
        {
            // var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext.initial ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_meta = Pomodoro.TimeBlockMeta () {
                cycle = scheduler.session_template.cycles,
                intended_duration = time_block.duration,
                is_completed = true
            };
            scheduler.resolve_context (time_block, time_block_meta, ref context);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.BREAK,
                cycle = scheduler.session_template.cycles,
                // needs_long_break = false,
                is_session_completed = true
            };
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }

        /**
         * Expect .resolve_context() with uncompleted long-break to indicate that long break is still needed.
         */
        public void test_resolve_context__uncompleted_long_break ()
        {
            // var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);
            var context = Pomodoro.SchedulerContext.initial ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            var time_block_meta = Pomodoro.TimeBlockMeta () {
                cycle = scheduler.session_template.cycles,
                intended_duration = time_block.duration,
                is_uncompleted = true
            };
            scheduler.resolve_context (time_block, time_block_meta, ref context);

            var expected_context = Pomodoro.SchedulerContext () {
                timestamp = time_block.end_time,
                state = Pomodoro.State.BREAK,
                cycle = scheduler.session_template.cycles,
                // needs_long_break = true,
                is_session_completed = false
            };
            assert_cmpvariant (
                context.to_variant (),
                expected_context.to_variant ()
            );
        }


        /**
         * Expect `resolve_time_block()` to return null for a completed session.
         */
        public void test_resolve_time_block__completed_session ()
        {
            var session = new Pomodoro.Session.from_template (this.session_template);
            var scheduler = new Pomodoro.StrictScheduler ();  //.with_template (this.session_template);

            // TODO
        }

        /**
         * Expect `resolve_time_block()` to return null when number of cycles exceed the template.
         */
        public void test_resolve_time_block__extra_cycles ()
        {
            // TODO
        }

        public void test_resolve_time_block__pomodoro ()
        {
            // TODO
        }

        public void test_resolve_time_block__short_break ()
        {
            // TODO
        }

        public void test_resolve_time_block__long_break ()
        {
            // TODO
        }


        /**
         * Populate empty session using scheduler.
         */
        public void test_reschedule__populate ()
        {
            var timestamp = Pomodoro.Timestamp.advance (0) + Pomodoro.Interval.MINUTE;
            var session = new Pomodoro.Session ();
            var scheduler = new Pomodoro.StrictScheduler.with_template (this.session_template);

            scheduler.reschedule (session, timestamp);
            assert_cmpuint (session.cycles, GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (timestamp)
            );
        }

        /**
         * Mark few time-block as uncompleted and reschedule future time-blocks.
         */
        public void test_reschedule__pomodoro ()
        {
            // TODO uncompleted pomodoro, completed pomodoro, extended pomodoro
        }

        public void test_reschedule__short_break ()
        {
            // TODO
        }

        public void test_reschedule__long_break ()
        {
            // TODO
        }

        /**
         * Rescheduling a session that has completed long-break shouldn't do anything.
         *
         * No upcoming time-block should force `SessionManager` to start new session.
         */
        public void test_reschedule__completed ()
        {
            // TODO
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.StrictSchedulerTest ()
    );
}
