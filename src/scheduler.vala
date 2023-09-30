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
        public bool           is_session_completed;
        public bool           needs_long_break;
        public double         score;

        public SchedulerContext ()
        {
            this.timestamp = Pomodoro.Timestamp.UNDEFINED;
            this.state = Pomodoro.State.UNDEFINED;
            this.is_session_completed = false;
            this.needs_long_break = false;
            this.score = 0.0;
        }

        public static Pomodoro.SchedulerContext initial (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            return SchedulerContext () {
                timestamp = timestamp,
            };
        }

        /**
         * Make context copy
         *
         * This function is unnecessary. Structs in vala are copied by default. It's kept
         * to bring more clarity to our code.
         */
        public Pomodoro.SchedulerContext copy ()
        {
            return this;
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
            builder.add ("{sv}", "is_session_completed", new GLib.Variant.boolean (this.is_session_completed));
            builder.add ("{sv}", "needs_long_break", new GLib.Variant.boolean (this.needs_long_break));
            builder.add ("{sv}", "score", new GLib.Variant.double (this.score));

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
            representation.append (@"    is_session_completed = $is_session_completed,\n");
            representation.append (@"    needs_long_break = $needs_long_break,\n");
            representation.append (@"    score = $score,\n");
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
         * Ratio of the elapsed time to intended duration.
         *
         * When set to 0.5 it would count two cycles per completed pomodoro. Reasonable values are > 0.667.
         */
        public const double MIN_PROGRESS = 0.8;

        /**
         * Max number of time-blocks scheduled in case scheduler enters into an infinite loop.
         */
        internal const uint MAX_ITERATIONS = 30;


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


        public int64 calculate_time_block_completion_time (Pomodoro.TimeBlock time_block)
        {
            var intended_duration = time_block.get_intended_duration ();

            if (Pomodoro.Timestamp.is_undefined (time_block.start_time)) {
                GLib.debug ("calculate_time_block_completion_time: `start_time` is not set");
                return Pomodoro.Timestamp.UNDEFINED;
            }

            if (intended_duration <= 0) {
                GLib.debug ("calculate_time_block_completion_time: `intended_duration` is not set");
                intended_duration = this.get_default_duration (time_block.state);
            }

            var remaining_elapsed = (int64) Math.floor (intended_duration * MIN_PROGRESS);
            var reference_time = time_block.start_time;

            time_block.foreach_gap (
                (gap) => {
                    if (Pomodoro.Timestamp.is_undefined (gap.end_time)) {
                        return;
                    }

                    var tmp = remaining_elapsed - (gap.start_time - reference_time);

                    if (tmp > 0) {
                        remaining_elapsed = tmp;
                        reference_time = gap.end_time;
                    }
                }
            );

            return reference_time + remaining_elapsed;
        }

        public abstract double calculate_time_block_score (Pomodoro.TimeBlock time_block,
                                                           int64              timestamp);

        public abstract double calculate_time_block_weight (Pomodoro.TimeBlock time_block);

        /**
         * Update given state according to given time-block.
         *
         * The context will hold info about current state of the session.
         */
        public abstract void resolve_context (Pomodoro.TimeBlock            time_block,
                                              ref Pomodoro.SchedulerContext context);

        /**
         * Resolve next time-block according to scheduler state.
         */
        public abstract Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context);

        /**
         * Check whether time-block can be marked as completed or uncompleted.
         *
         * It assumes that we reached time-block end-time. Set time-block time range before calling this function.
         */
        public abstract bool is_time_block_completed (Pomodoro.TimeBlock time_block);

        /**
         * Build a scheduler context from completed/in-progress time-blocks.
         */
        internal void build_scheduler_context (Pomodoro.Session                          session,
                                               int64                                     timestamp,
                                               out Pomodoro.SchedulerContext             context,
                                               out unowned GLib.List<Pomodoro.TimeBlock> first_scheduled_link)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = session.time_blocks.first ();

            context = Pomodoro.SchedulerContext.initial (
                link != null && link.data.get_status () != Pomodoro.TimeBlockStatus.SCHEDULED
                ? link.data.start_time
                : timestamp);
            first_scheduled_link = null;

            while (link != null && !context.is_session_completed)
            {
                var time_block = link.data;

                if (time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED)
                {
                    first_scheduled_link = link;
                    break;
                }

                this.resolve_context (time_block, ref context);

                link = link.next;
            }
        }

        protected int64 get_default_duration (Pomodoro.State state)
        {
            switch (state)
            {
                case Pomodoro.State.POMODORO:
                    return this.session_template.pomodoro_duration;

                case Pomodoro.State.SHORT_BREAK:
                    return this.session_template.short_break_duration;

                case Pomodoro.State.LONG_BREAK:
                    return this.session_template.long_break_duration;

                default:
                    assert_not_reached ();
            }
        }

        public void reschedule_time_block (Pomodoro.TimeBlock time_block,
                                           int64              timestamp = Pomodoro.Timestamp.UNDEFINED)
                                           requires (time_block.state != Pomodoro.State.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            // TODO: adjust session template according to available time

            time_block.set_time_range (timestamp, timestamp + this.get_default_duration (time_block.state));
            time_block.set_intended_duration (time_block.duration);
            time_block.set_completion_time (this.calculate_time_block_completion_time (time_block));
            time_block.set_weight (this.calculate_time_block_weight (time_block));
        }

        /**
         * Reschedule time-blocks if needed.
         *
         * It will affect time-blocks not marked as completed or uncompleted. May add/remove time-blocks.
         *
         * `next_time_block` - indicates a time-block that is in-progress of is selected to be in-progress.
         */
        // TODO: rename to reschedule_session
        public void reschedule (Pomodoro.Session    session,
                                Pomodoro.TimeBlock? next_time_block = null,
                                int64               timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            Pomodoro.SchedulerContext context;
            Pomodoro.TimeBlock time_block;
            unowned GLib.List<Pomodoro.TimeBlock> link;

            // Jump to first scheduled time-block.
            this.build_scheduler_context (session, timestamp, out context, out link);

            var is_populating = next_time_block == null
                ? session.time_blocks.is_empty ()
                : session.time_blocks.length () == 1 && session.time_blocks.first ().data == next_time_block;
            var n = 1;

            session.freeze_changed ();

            // Remove scheduled time-blocks until next_time_block and shift the time-block to the timestamp.
            if (next_time_block != null)
            {
                assert (next_time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

                while (link != null && link.data != next_time_block)
                {
                    unowned GLib.List<Pomodoro.TimeBlock> tmp = link.next;
                    session.remove_link (link);
                    link = tmp;
                }

                this.reschedule_time_block (next_time_block, timestamp);
            }

            // Create or update time-blocks.
            while (true)
            {
                var existing_time_block = link != null ? link.data : null;

                if (n++ >= Pomodoro.Scheduler.MAX_ITERATIONS) {
                    GLib.error ("`Session.reschedule()` reached iterations limit.");
                    // break;
                }

                if (next_time_block != null) {
                    time_block = next_time_block;
                    next_time_block = null;
                }
                else {
                    time_block = this.resolve_time_block (context);

                    if (time_block == null) {
                        break;
                    }
                }

                if (existing_time_block != null && existing_time_block.state == time_block.state)
                {
                    // Update existing time-block.
                    existing_time_block.set_time_range (time_block.start_time, time_block.end_time);
                    existing_time_block.set_meta (time_block.get_meta ());

                    time_block = existing_time_block;
                    link = link.next;
                }
                else {
                    // Add new time-block.
                    if (link != null) {
                        session.time_blocks.insert_before (link, time_block);
                    }
                    else {
                        session.time_blocks.append (time_block);
                    }

                    session.emit_added (time_block);
                }

                this.resolve_context (time_block, ref context);
            }

            // Remove time-blocks after a long-break.
            session.remove_links_after (link);
            session.remove_link (link);

            session.thaw_changed ();

            if (is_populating) {
                this.populated_session (session);
            }
            else {
                this.rescheduled_session (session);
            }
        }

        public bool is_long_break_needed (Pomodoro.Session session,
                                          int64            timestamp)
        {
            Pomodoro.SchedulerContext context;

            this.build_scheduler_context (session, timestamp, out context, null);

            return context.needs_long_break;
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

        private double calculate_time_block_score_internal (Pomodoro.TimeBlock time_block,
                                                            bool               include_uncompleted_gaps,
                                                            int64              timestamp)
        {
            var time_block_meta = time_block.get_meta ();

            if (time_block.state != Pomodoro.State.POMODORO ||
                time_block_meta.status == Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                return 0.0;
            }

            if (Pomodoro.Timestamp.is_undefined (time_block_meta.completion_time)) {
                GLib.debug ("calculate_time_block_score: `completion_time` is not set");
                time_block_meta.completion_time = this.calculate_time_block_completion_time (time_block);
            }

            if (time_block_meta.intended_duration <= 0) {
                GLib.debug ("calculate_time_block_score: `intended_duration` is not set");
                time_block_meta.intended_duration = this.get_default_duration (time_block.state);
            }

            if (time_block.end_time < time_block_meta.completion_time) {
                return 0.0;
            }

            var elapsed = time_block.calculate_elapsed (timestamp);
            var elapsed_target = time_block.calculate_elapsed (time_block_meta.completion_time);
            var last_gap = time_block.get_last_gap ();

            if (include_uncompleted_gaps &&
                last_gap != null &&
                Pomodoro.Timestamp.is_undefined (last_gap.end_time) &&
                timestamp > last_gap.start_time)
            {
                elapsed = Pomodoro.Interval.subtract (elapsed,
                                                      Pomodoro.Timestamp.subtract (timestamp, last_gap.start_time));
            }

            var base_score = elapsed / time_block_meta.intended_duration;
            var score = (double) base_score;

            if (elapsed_target > 0) {
                score += (double) ((elapsed - (int64) (base_score * time_block_meta.intended_duration)) /
                                   elapsed_target);
            }

            return score;
        }

        public override double calculate_time_block_score (Pomodoro.TimeBlock time_block,
                                                           int64              timestamp)
        {
            return this.calculate_time_block_score_internal (time_block, true, time_block.end_time);
        }

        public override double calculate_time_block_weight (Pomodoro.TimeBlock time_block)
        {
            return this.calculate_time_block_score_internal (time_block, false, time_block.end_time);
        }

        public override void resolve_context (Pomodoro.TimeBlock            time_block,
                                              ref Pomodoro.SchedulerContext context)
        {
            var timestamp = time_block.end_time;
            var time_block_weight = this.calculate_time_block_weight (time_block);

            // Treat scheduled and in-progress time-blocks as if they will be completed according to plan.
            context.state = time_block.state;
            context.timestamp = timestamp;

            if (!time_block_weight.is_nan ()) {
                context.score += time_block_weight;
            }

            if (time_block.get_status () != Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                if (time_block.state == Pomodoro.State.LONG_BREAK) {
                    context.is_session_completed = true;
                }

                context.needs_long_break = !context.is_session_completed &&
                                            context.score >= this.session_template.cycles;
            }
        }

        /**
         * Create next time-block.
         *
         * Alternate between a pomodoro and a break, regardless whether previous time-block has been completed.
         */
        public override Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerContext context)
        {
            if (context.is_session_completed) {
                return null;  // Suggest starting a new session.
            }

            var state = context.state == Pomodoro.State.POMODORO
                ? (context.needs_long_break ? Pomodoro.State.LONG_BREAK : Pomodoro.State.SHORT_BREAK)
                : Pomodoro.State.POMODORO;
            var time_block = new Pomodoro.TimeBlock (state);
            time_block.set_is_extra (state != Pomodoro.State.LONG_BREAK && context.needs_long_break);

            this.reschedule_time_block (time_block, context.timestamp);

            return time_block;
        }

        /**
         * Determine whether time-block should be marked as completed after the new `TimeBlock.end_time` has been set.
         *
         * It does not take into account current status.
         */
        public override bool is_time_block_completed (Pomodoro.TimeBlock time_block)
        {
            var completion_time = time_block.get_completion_time ();

            if (Pomodoro.Timestamp.is_undefined (completion_time)) {
                GLib.debug ("is_time_block_completed: `completion_time` is not set");
                return false;
            }

            if (Pomodoro.Timestamp.is_undefined (time_block.end_time)) {
                GLib.debug ("is_time_block_completed: `end_time` is not set");
                return false;
            }

            return time_block.end_time >= completion_time;
        }
    }
}
