namespace Pomodoro
{
    /**
     * Structure describing current cycle or energy level within a session.
     *
     * For simplicity, same structure is shared between all schedulers. Which accidentally also allows
     * changing a strategy during session.
     */
    public struct SchedulerContext
    {
        public int64          timestamp;
        public Pomodoro.State state;
        public uint           cycle;
        public bool           is_cycle_completed;
        public bool           is_session_completed;
        public bool           needs_long_break;
        public double         energy;

        public SchedulerContext ()
        {
            this.timestamp = Pomodoro.Timestamp.UNDEFINED;
            this.state = Pomodoro.State.UNDEFINED;
            this.cycle = 0;
            this.is_cycle_completed = false;
            this.is_session_completed = false;
            this.needs_long_break = false;
            this.energy = 1.0;
        }

        public static Pomodoro.SchedulerContext initial (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            return SchedulerContext () {
                timestamp = timestamp,
            };
        }

         /**
         * Convert structure to Variant.
         *
         * Used in tests.
         */
        public GLib.Variant to_variant ()
        {
            var builder = new GLib.VariantBuilder (new GLib.VariantType ("a{s*}"));
            builder.add ("{sv}", "timestamp", new GLib.Variant.int64 (this.timestamp));
            builder.add ("{sv}", "state", new GLib.Variant.string (this.state.to_string ()));
            builder.add ("{sv}", "cycle", new GLib.Variant.uint16 ((uint16) this.cycle));
            builder.add ("{sv}", "is_cycle_completed", new GLib.Variant.boolean (this.is_cycle_completed));
            builder.add ("{sv}", "is_session_completed", new GLib.Variant.boolean (this.is_session_completed));
            builder.add ("{sv}", "needs_long_break", new GLib.Variant.boolean (this.needs_long_break));
            builder.add ("{sv}", "energy", new GLib.Variant.double (this.energy));

            return builder.end ();
        }

        /**
         * Represent context as string.
         *
         * Used in tests.
         */
        public string to_representation ()
        {
            var state_string = this.state.to_string ();

            var representation = new GLib.StringBuilder ("SchedulerContext (\n");
            representation.append (@"    timestamp = $timestamp,\n");
            representation.append (@"    state = $state_string,\n");
            representation.append (@"    cycle = $cycle,\n");
            representation.append (@"    is_cycle_completed = $is_cycle_completed,\n");
            representation.append (@"    is_session_completed = $is_session_completed,\n");
            representation.append (@"    needs_long_break = $needs_long_break,\n");
            representation.append (@"    energy = $energy,\n");
            representation.append (")");

            return representation.str;
        }
    }


    /**
     * Scheduler helps in determining next time-block in a session.
     *
     * It works in a step-wise fashion. It tries to make a best guess according to `SchedulerContext`.
     *
     * In future we would like to align time-blocks to calendar events and working time.
     */
    public abstract class Scheduler : GLib.Object
    {
        public const int64 MIN_ELAPSED = 10 * Pomodoro.Interval.SECOND;
        public const int64 MIN_DURATION = Pomodoro.Interval.MINUTE;

        public Pomodoro.SessionTemplate session_template { get; set; }

        /**
         * Update given state according to given time-block.
         *
         * The context will hold info about current state of the session.
         */
        public abstract void resolve_context (Pomodoro.TimeBlock            time_block,
                                              Pomodoro.TimeBlockMeta        time_block_meta,
                                              ref Pomodoro.SchedulerContext context);

        /**
         * Resolve next time-block according to scheduler state.
         */
        public abstract Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context);

        /**
         * Check whether time-block can be marked as completed or uncompleted.
         *
         * It assumes that we reached time-block end-time. Trim the time-block before calling this function.
         */
        public abstract bool is_time_block_completed (Pomodoro.TimeBlock     time_block,
                                                      Pomodoro.TimeBlockMeta time_block_meta,
                                                      int64                  timestamp);

        // /**
        //  * Check whether upcoming break should be a long one.
        //  */
        // public abstract bool is_long_break_needed (Pomodoro.SchedulerContext context);

        /**
         * Reschedule time-blocks if needed.
         *
         * It will affect time-blocks not marked as completed or uncompleted. May add/remove time-blocks.
         */
        public void reschedule (Pomodoro.Session session,
                                int64            timestamp = -1)
        {
            session.reschedule (this, timestamp);
        }
    }


    public class StrictScheduler : Scheduler
    {
        public StrictScheduler.with_template (Pomodoro.SessionTemplate session_template)
        {
            GLib.Object (
                session_template: session_template
            );
        }

        public uint calculate_cycles_completed (Pomodoro.TimeBlock     time_block,
                                                Pomodoro.TimeBlockMeta time_block_meta,
                                                int64                  timestamp = -1)
        {
            if (time_block.duration < MIN_DURATION) {
                return 0;
            }

            if (time_block_meta.intended_duration == 0) {
                GLib.debug ("Can't tell whether time-block has completed. There is no `intended_duration`.");
                return 0;
            }

            var elapsed     = Pomodoro.Timestamp.round_seconds (time_block.calculate_elapsed (timestamp));
            var min_elapsed = int64.max (time_block_meta.intended_duration / 2, MIN_ELAPSED);
            var cycles      = Pomodoro.Interval.add (elapsed, min_elapsed) / time_block_meta.intended_duration;

            return (uint) int64.min (cycles, uint.MAX);
        }

        public override void resolve_context (Pomodoro.TimeBlock            time_block,
                                              Pomodoro.TimeBlockMeta        time_block_meta,
                                              ref Pomodoro.SchedulerContext context)
        {
            context.state = time_block.state;

            if (Pomodoro.Timestamp.is_defined (time_block.end_time)) {
                context.timestamp = time_block.end_time;
            }
            else if (Pomodoro.Timestamp.is_defined (time_block.start_time)) {
                context.timestamp = time_block.start_time;
            }

            if (context.cycle == 0) {
                // Immediately treat initial cycle as completed in order to schedule a pomodoro.
                // This behaviour is debatable, as the cycle hasn't really been completed; if we can call
                // a cycle without a pomodoro - a cycle.
                context.is_cycle_completed = true;
            }

            if (time_block.state == Pomodoro.State.POMODORO)
            {
                if (time_block_meta.is_scheduled ()) {
                    // For scheduled time-blocks pretend that cycles are completed
                    // in order to resolve context.
                    context.is_cycle_completed = true;
                }

                // GLib.debug (
                //     "is_scheduled = %s, is_cycle_completed = %s",
                //     time_block_meta.is_scheduled () ? "true" : "false",
                //     context.is_cycle_completed ? "true" : "false"
                // );

                if (context.is_cycle_completed) {
                    context.cycle++;
                    context.is_cycle_completed = false;
                    context.needs_long_break = context.cycle >= this.session_template.cycles;
                }

                if (time_block_meta.is_completed)
                {
                    var cycles_completed = this.calculate_cycles_completed (time_block, time_block_meta, context.timestamp);

                    // Long pomodoros may count as multiple cycles.
                    if (cycles_completed > 1) {
                        context.cycle += cycles_completed - 1;
                    }

                    context.is_cycle_completed = true;
                }
            }

            // if (!context.needs_long_break) {
                // debug ("%u / %u", context.cycle, this.session_template.cycles);
            // }

            if (time_block_meta.is_long_break && (time_block_meta.is_completed || time_block_meta.is_scheduled ())) {
                context.is_session_completed = true;
            }
        }

        /**
         * Alternate between pomodoro and a break, regardless whether previous time-block has been completed.
         */
        public override Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context)
        {
            // Suggest to start new session.
            if (context.is_session_completed) {
                return null;
            }

            // Ensure last cycle ends with a break.
            // if (context.state != Pomodoro.State.POMODORO && context.cycle >= this.session_template.cycles) {
            //     return null;
            // }

            var time_block = new Pomodoro.TimeBlock.with_start_time (
                context.timestamp,
                context.state == Pomodoro.State.POMODORO ? Pomodoro.State.BREAK : Pomodoro.State.POMODORO,
                Pomodoro.Source.SCHEDULER);

            // TODO: adjust session template according to available time
            var session_template = this.session_template;

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    time_block.duration = session_template.pomodoro_duration;
                    break;

                case Pomodoro.State.BREAK:
                    time_block.duration = context.needs_long_break
                        ? session_template.long_break_duration
                        : session_template.short_break_duration;
                    break;

                default:
                    assert_not_reached ();
            }

            return time_block;
        }

        public override bool is_time_block_completed (Pomodoro.TimeBlock     time_block,
                                                      Pomodoro.TimeBlockMeta time_block_meta,
                                                      int64                  timestamp = -1)
        {
            return this.calculate_cycles_completed (time_block, time_block_meta, timestamp) > 0;
        }

        // public override bool is_long_break_needed (Pomodoro.SchedulerContext context)
        // {
        //     debug (
        //         "is_long_break_needed: context.is_cycle_completed = %s",
        //         context.is_cycle_completed ? "true" : "false"
        //     );
        //     return !context.is_session_completed &&
        //             context.cycle >= this.session_template.cycles &&
        //             context.is_cycle_completed;
        // }
    }
}





        // /**
        //  * Check whether you .
        //  *
        //  * It assumes that we reached time-block end-time. Trim the time-block before calling this function.
        //  */
        // public abstract bool should_take_long_break (Pomodoro.SchedulerState state);



        // public override bool should_take_long_break (Pomodoro.SchedulerState state)
        // {
        //     return state.current_cycle >= this.session_template.cycles;
        // }



        /**
         * Figure out current state of the session.
         */
        // public abstract Pomodoro.SchedulerState resolve_state (Pomodoro.Session session,
        //                                                        int64            timestamp = -1);



        // public void reschedule (Pomodoro.Session session,
        //                         int64            timestamp = -1)
        // {
        // }

        // /**
        //  * Reschedule time-blocks if needed.
        //  *
        //  * It will affect time-blocks not marked as completed or uncompleted. May add/remove time-blocks.
        //  */
        // public void reschedule (Pomodoro.Session session,
        //                         int64            timestamp = -1)
        // {
        //     session.reschedule (this, timestamp);


            // Pomodoro.ensure_timestamp (ref timestamp);

            // Pomodoro.SchedulerState  state;
            // Pomodoro.TimeBlockMeta[] scheduled_time_blocks_meta;

            // this.prepare_reschedule (session, out state, out scheduled_time_blocks_meta);

            // session.freeze_changed ();

            // session.@foreach_meta (
            //     (time_block_meta) => {
            //         if (time_block_meta.is_completed || time_block_meta.is_uncompleted) {
            //             this.resolve_state (time_block_meta, ref state);
            //         }
            //         else {
            //             scheduled_time_blocks_meta += time_block_meta;
            //         }
            //     }
            // );

            // while (true) {
            //     var time_block = this.resolve_time_block (state);
            //     var existing_time_block = this.match_time_block (session, time_block)

            //     session.insert_after (time_block);

            //     var time_block_meta = session.get_time_block_meta (time_block);
            //     this.resolve_state (time_block_meta, ref state);
            // }

            // session.thaw_changed ();
        // }

        // private Pomodoro.TimeBlockMeta[] get_session_time_blocks ()
        // {
        //     var state = Pomodoro.SchedulerState ();
            // var time_blocks = this.get_scheduled_time_blocks (session);
        //     Pomodoro.TimeBlockMeta scheduled_time_blocks_meta;

        //     session.@foreach_meta (
        //         (time_block_meta) => {
        //             if (time_block_meta.is_completed || time_block_meta.is_uncompleted) {
        //                 this.resolve_state (time_block_meta, ref state);
        //             }
        //             else {
        //                 scheduled_time_blocks_meta += time_block_meta;
        //             }
        //         }
        //     );
        // }

        // private Pomodoro.TimeBlockMeta[] get_state ()
        // {
        // }

        // var time_blocks = this.get_scheduled_time_blocks (session);

        // private void prepare_reschedule (Pomodoro.Session             session,
        //                                  out Pomodoro.SchedulerState  state,
        //                                  out Pomodoro.TimeBlockMeta[] scheduled_time_blocks_meta)
        // {
        //     var resolving_state = true;
        //     state = Pomodoro.SchedulerState () {
        //         current_state = Pomodoro.State.POMODORO,
        //         current_cycle = 0,
        //         needs_long_break = false,
        //         energy = 1.0
        //     };

            // TODO
            // session.@foreach_meta (
            //     (time_block_meta) => {
            //         if (resolving_state && (time_block_meta.is_completed || time_block_meta.is_uncompleted)) {
            //             this.resolve_state (time_block_meta, ref state);
            //         }
            //         else {
            //             resolving_state = false;
            //             scheduled_time_blocks_meta += time_block_meta;
            //         }
            //     }
            // );
        // }




        // public Pomodoro.TimeBlockMeta[] get_scheduled_time_blocks (Pomodoro.Session session)
        // {
        //     Pomodoro.TimeBlockMeta[] time_blocks_meta;

        //     session.@foreach_meta ((time_block_meta) => {
        //         if (!time_block_meta.is_completed && !time_block_meta.is_uncompleted) {
        //             time_blocks_meta += time_block_meta;
        //         }
        //     }

        //     return time_blocks_meta;
        // }


        // /**
        //  * Fit time-block to first available slot.
        //  *
        //  * Try to preserve time blocks original duration.
        //  * It must be autonomous - pick best candidate in case of conflict.
        //  */
        // public bool fit (Pomodoro.TimeBlock time_block,
        //                  int64              minimum_start_time,
        //                  int64              natural_start_time)
        // {
            // TODO

        //     return true;
        // }

        // /**
        //  * Fit time-blocks to available time.
        //  *
        //  * Like `fit()`, but additionally allows to spread time-blocks more evenly in case of conflict.
        //  */
        // public bool fit_many (Pomodoro.TimeBlock[] time_blocks,
        //                       int64                minimum_start_time,
        //                       int64                natural_start_time)
        // {
            // TODO

        //     return true;
        // }
