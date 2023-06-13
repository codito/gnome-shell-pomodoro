namespace Pomodoro
{
    /**
     * Structure describing current cycle or energy level within a session.
     *
     * For simplicity, the same structure is shared between all schedulers.
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

        public static Pomodoro.SchedulerContext initial (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
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
        /**
         * Time threshold below which to discard a time-block, it won't be recorded in history.
         */
        public const int64 MIN_ELAPSED = 10 * Pomodoro.Interval.SECOND;

        /**
         * Time threshold below which to discard a time-block, it won't be recorded in history.
         */
        public const int64 MIN_DURATION = Pomodoro.Interval.MINUTE;

        /**
         * Max number of time-blocks scheduled in case scheduler enters into an infinite loop.
         */
        internal const uint MAX_ITERATIONS = 1000;


        [CCode(notify = false)]
        public Pomodoro.SessionTemplate session_template {
            get {
                return this._session_template;
            }
            set {
                if (this._session_template.equals (value)) {
                    return;
                }

                this._session_template = value;

                this.notify_property ("session-template");
            }
        }

        private Pomodoro.SessionTemplate _session_template;


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

        /**
         * Reschedule time-blocks if needed.
         *
         * It will affect time-blocks not marked as completed or uncompleted. May add/remove time-blocks.
         *
         * `next_time_block` - indicates a time-block that is in-progress of is selected to be in-progress.
         */
        public void reschedule (Pomodoro.Session    session,
                                Pomodoro.TimeBlock? next_time_block = null,
                                int64               timestamp = -1)
        {
            session.reschedule (this, next_time_block, timestamp);
        }

        public signal void populated_session (Pomodoro.Session session);

        public signal void rescheduled_session (Pomodoro.Session session);
    }


    public class SimpleScheduler : Scheduler
    {
        public SimpleScheduler.with_template (Pomodoro.SessionTemplate session_template)
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
                GLib.warning ("Can't tell whether time-block has completed. There is no `intended_duration`.");
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
                // Start new cycle with first pomodoro.
                if (context.is_cycle_completed) {
                    context.cycle++;
                    context.is_cycle_completed = false;
                }

                // For scheduled time-blocks assume best-case scenario, that they will get completed
                // as planned. Cycle need to be marked as completed in order to schedule next cycles.
                if (time_block_meta.status <= Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    context.is_cycle_completed = true;
                }

                // Count completed pomodoros / cycles, even if time-block is in progress.
                if (time_block_meta.status != Pomodoro.TimeBlockStatus.SCHEDULED)
                {
                    var cycles_completed = this.calculate_cycles_completed (time_block, time_block_meta, context.timestamp);

                    if (cycles_completed > 1) {
                        context.cycle += cycles_completed - 1;
                    }

                    if (!context.is_cycle_completed) {
                        context.is_cycle_completed = cycles_completed > 0;
                    }
                }

                context.needs_long_break = context.cycle > this.session_template.cycles ||
                                           context.cycle == this.session_template.cycles && context.is_cycle_completed;
            }

            if (time_block.state == Pomodoro.State.LONG_BREAK &&
                time_block_meta.status != Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                context.is_session_completed = true;
            }
        }

        /**
         * Alternate between pomodoro and a break, regardless whether previous time-block has been completed.
         */
        public override Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context)
        {
            // Suggest to start a new session.
            if (context.is_session_completed) {
                return null;
            }

            var state = context.state == Pomodoro.State.POMODORO
                ? (context.needs_long_break ? Pomodoro.State.LONG_BREAK : Pomodoro.State.SHORT_BREAK)
                : Pomodoro.State.POMODORO;
            var time_block = new Pomodoro.TimeBlock.with_start_time (
                context.timestamp,
                state,
                Pomodoro.Source.SCHEDULER);

            // TODO: adjust session template according to available time
            var session_template = this.session_template;

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    time_block.duration = session_template.pomodoro_duration;
                    break;

                case Pomodoro.State.SHORT_BREAK:
                    time_block.duration = session_template.short_break_duration;
                    break;

                case Pomodoro.State.LONG_BREAK:
                    time_block.duration = session_template.long_break_duration;
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
    }
}
