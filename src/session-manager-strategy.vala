namespace Pomodoro
{
    // TODO: review these:
    /* Minimum time in seconds for pomodoro to get scored. */
    internal const double MIN_POMODORO_TIME = 60.0;

    /* Minimum progress for pomodoro to be considered for a long break. Higer values means
       the timer is more strict about completing pomodoros. */
    internal const double POMODORO_THRESHOLD = 0.90;

    /* Acceptable score value that can be missed during cycle. */
    internal const double MISSING_SCORE_THRESHOLD = 0.50;

    /* Minimum progress for long break to get accepted. It's in reference to duration of a short break,
       or more precisely it's a ratio between duration of a short break and a long break. */
    internal const double SHORT_TO_LONG_BREAK_THRESHOLD = 0.50;


    public abstract class SessionManagerStrategy : GLib.Object
    {
        /**
         * Reschedule future time blocks in a session - this can include removing/adding future time blocks.
         *
         * Base implementation discards past time-blocks shorter than 1 minute, marks them as skipped.
         * Also, remove future time blocks after being idle for 1h.
         *
         */
        public virtual void reschedule (Pomodoro.Session session,
                                        int64            timestamp = -1)
        {
            // TODO

            // var link =
        }

        // public void reschedule (Pomodoro.TimeBlock time_block,
        //                         int64              start_time)
        // {
        //     var offset = start_time - time_block.start_time;
        //     var changing = false;
        //
        //     if (offset == 0) {
        //         return;
        //     }
        //
        //     this.time_blocks.@foreach ((scheduled_time_block) => {
        //         if (scheduled_time_block == time_block) {
        //             changing = true;
        //         }
        //
        //         if (changing) {
        //             scheduled_time_block.move_by (offset);
        //         }
        //     });
        // }
    }


    /**
     * Loose strategy prioritizes number of cycles. Only 1 minute in a pomodoro is needed to mark it as completed.
     *
     * It's meant to be predictable as to when the long break will occur.
     */
    // public class LooseSessionManagerStrategy : SessionManagerStrategy  // TODO: remove?
    // {
    //     public override void reschedule (Pomodoro.Session session,
    //                                      int64            timestamp = -1)
    //     {
    //         Pomodoro.ensure_timestamp (ref timestamp);
    //
    //         base.reschedule (session, timestamp);
    //
    //         // TODO
    //     }
    // }


    /**
     * In a strict strategy pomodoro blocks needs to be completed in 100% to be regarded as completed.
     *
     * In other words, if you don't complete pomodoros in full, it pospones a long break as a penalty.
     */
    public class StrictSessionManagerStrategy : SessionManagerStrategy
    {
        // public void handle_timer_resolve_state (Pomodoro.Timer          timer,
        //                                         ref Pomodoro.TimerState state)
        // {
        //     var current_time_block = (unowned Pomodoro.TimeBlock) state.user_data;
        // }

        /**
         *
         */
        public void handle_timer_state_changed (Pomodoro.Timer      timer,
                                                Pomodoro.TimerState current_state,
                                                Pomodoro.TimerState previous_state)
        {
            var current_time_block = current_state.user_data as Pomodoro.TimeBlock;

            // Pomodoro.TimeBlock  time_block,

            // Pomodoro.ensure_timestamp (ref timestamp);

            // TODO
        }

        public void handle_timer_suspended (Pomodoro.Timer timer,
                                            int64          start_time,
                                            int64          end_time)
        {
            var current_time_block = timer.state.user_data as Pomodoro.TimeBlock;
        }

        public void handle_timer_finished (Pomodoro.Timer      timer,
                                           Pomodoro.TimerState state)
        {
        }

        // public override void skip (Pomodoro.Session session,
        //                            int64            timestamp = -1)

        // public override void is_time_block_completed ()
        // {
        // }

        // public override void is_cycle_completed (Pomodoro.Cycle cycle,
        //                                          int64          timestamp = -1)
        // {
        // }

        /**
         *
         */
        public override void reschedule (Pomodoro.Session session,
                                         int64            timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            base.reschedule (session, timestamp);

            // TODO
        }
    }


    /**
     * Adaptive strategy prioritizes work-to-break ratio.
     *
     * Pomodoros are counted according to elapsed time - so you can interrupt timer, complete two halves of pomodoro,
     * and it will be counted as one pomodoro. When user is skipping breaks, a long break may be scheduled earlier
     * than planned.
     *
     * Timeblocks shorter than 1 minute are discarded.
     */
    public class AdaptiveSessionManagerStrategy : SessionManagerStrategy
    {
        public override void reschedule (Pomodoro.Session session,
                                         int64            timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            base.reschedule (session, timestamp);

            // TODO
        }
    }
}
