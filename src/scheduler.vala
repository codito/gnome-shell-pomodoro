namespace Pomodoro
{
    /**
     * Structure describing current cycle or energy level within a session.
     *
     * For simplicity, same structure is shared between all schedulers. Which also allows
     * changing a strategy during session.
     *
     * Perhaps it `context` would be a more appropriate name, but for project consistency its `state`.
     */
    public struct SchedulerState
    {
        public int64          timestamp;
        public Pomodoro.State state;
        public uint           cycle;
        public bool           is_long_break_pending;
        public double         energy;
    }


    /**
     * Scheduler helps in determining next time-block in a session.
     *
     * It works in a step-wise fashion. It tries to make a best guess according to `SchedulerState`.
     *
     * In future we would like to align time-blocks to calendar events and working time.
     */
    public abstract class Scheduler : GLib.Object
    {
        public const int64 MIN_ELAPSED = 10 * Pomodoro.Interval.SECOND;
        public const int64 MIN_DURATION = Pomodoro.Interval.MINUTE;

        // TODO: session template should be adjusted according to available time
        public Pomodoro.SessionTemplate session_template {
            get;
            set;
        }

        /**
         * Update given state according to given time-block.
         */
        public abstract void resolve_state (Pomodoro.TimeBlockMeta      time_block_meta,
                                            ref Pomodoro.SchedulerState state);

        /**
         * Resolve next time-block according to scheduler state.
         */
        public abstract Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerState state);

        /**
         * Check whether time-block can be marked as completed or uncompleted.
         *
         * It assumes that we reached time-block end-time. Trim the time-block before calling this function.
         */
        public abstract bool is_time_block_completed (Pomodoro.TimeBlockMeta time_block_meta);

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
        public override void resolve_state (Pomodoro.TimeBlockMeta      time_block_meta,
                                            ref Pomodoro.SchedulerState state)
        {
            // state = SchedulerState () {
            //     current_state = Pomodoro.State.UNDEFINED,
            //     current_cycle = 0,
            //     needs_long_break = false,
            //     energy = 1.0
            // };

            //     return state.current_cycle >= this.session_template.cycles;

            // TODO
        }

        public override Pomodoro.TimeBlock? resolve_time_block (Pomodoro.SchedulerState state)
        {
            var time_block = new Pomodoro.TimeBlock ();

            // TODO

            return time_block;
        }

        public override bool is_time_block_completed (Pomodoro.TimeBlockMeta time_block_meta)
        {
            var time_block  = time_block_meta.time_block;
            var elapsed     = Pomodoro.Timestamp.round_seconds (time_block.calculate_elapsed (time_block.end_time));
            var min_elapsed = int64.max (time_block_meta.intended_duration / 2, MIN_ELAPSED);

            return time_block.duration >= MIN_DURATION &&
                   elapsed >= min_elapsed;
        }
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
