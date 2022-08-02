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


    /*
    private void foreach_future_time_block (Pomodoro.Session    session,
                                            Pomodoro.TimeBlock? current_or_previous_time_block,
                                            GLib.Func<unowned Pomodoro.TimeBlock> func)
    {
        var current_or_previous_time_block;

        if (current_or_previous_time_block != null && current_or_previous_time_block.session != session) {
            current_or_previous_time_block = null;
        }

        // var skip_count = current_or_previous_time_block != null && this.session_manager.current_session == session
        //     ? this.session_manager.current_session.index (current_or_previous_time_block)
        //     : 0;
        var skipping = current_or_previous_time_block != null;

        session.freeze_changed ();
        session.@foreach (time_block => {
            if (skipping) {
                if (time_block == current_or_previous_time_block) {
                    skipping = false;
                }
            }
            else {
                time_block.move_to (previous_end_time);
            }

            previous_end_time = time_block.end_time;
        });
        session.thaw_changed ();
    }
    */


    /**
     * A "strategy" modifies a session according to timer changes.
     */
    public abstract class SessionManagerStrategy : GLib.Object
    {
        protected weak Pomodoro.SessionManager session_manager;
        protected weak Pomodoro.Timer          timer;

        public virtual void initialize (Pomodoro.SessionManager session_manager)
        {
            this.session_manager = session_manager;
            this.timer           = session_manager.timer;

            // TODO: setup handlers here, rather than exposing public methods
        }

        public virtual void handle_session_manager_enter_time_block (Pomodoro.SessionManager session_manager,
                                                                     Pomodoro.TimeBlock      time_block)
        {
        }

        public virtual void handle_session_manager_leave_time_block (Pomodoro.SessionManager session_manager,
                                                                     Pomodoro.TimeBlock      time_block)
        {
        }

        /**
         *
         */
        public virtual void handle_timer_state_changed (Pomodoro.Timer      timer,
                                                        Pomodoro.TimerState current_state,
                                                        Pomodoro.TimerState previous_state)
        {
        }

        public virtual void handle_timer_finished (Pomodoro.Timer      timer,
                                                   Pomodoro.TimerState state)
        {
        }

        public virtual void handle_timer_suspended (Pomodoro.Timer timer,
                                                    int64          start_time,
                                                    int64          end_time)
        {
        }

        // public virtual void handle_timer_state_change (Pomodoro.TimeBlock time_block,
        //                                                    int64              timestamp = -1)
        // {
        // }

        // public virtual void handle_time_block_ended (Pomodoro.TimeBlock time_block,
        //                                              int64              timestamp = -1)
        // {
        // }

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
            Pomodoro.ensure_timestamp (ref timestamp);

            var previous_end_time              = timestamp;
            var current_or_previous_time_block = this.session_manager.get_current_or_previous_time_block ();
            var skipping                       = current_or_previous_time_block != null;

            // TODO: use time_bloc.has_started instead of sesion-manager

            if (current_or_previous_time_block != null && current_or_previous_time_block.session != session) {
                current_or_previous_time_block = null;
                skipping = false;
            }

            session.freeze_changed ();
            session.@foreach (time_block => {
                if (skipping) {
                    if (time_block == current_or_previous_time_block) {
                        skipping = false;
                    }
                }
                else {
                    time_block.move_to (previous_end_time);
                }

                previous_end_time = time_block.end_time;
            });
            session.thaw_changed ();
        }


            /*
            // get index of a first future timeblock
            var skip_count = current_or_previous_time_block != null && this.session_manager.current_session == session
                ? this.session_manager.current_session.index (current_or_previous_time_block)
                : 0;
            debug ("reschedule: skip_count=%d", skip_count);

            session.freeze_changed ();
            session.@foreach (time_block => {
                if (skip_count >= 0 && time_block.start_time < previous_end_time) {
                    time_block.move_to (previous_end_time);
                }

                skip_count--;
                previous_end_time = time_block.end_time;
            });

            // TODO: add extra cycles

            session.thaw_changed ();
            */



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
        public override void handle_session_manager_enter_time_block (Pomodoro.SessionManager session_manager,
                                                                      Pomodoro.TimeBlock      time_block)
        {
            // time_block.set_data<bool> ("started", true);
        }

        public override void handle_session_manager_leave_time_block (Pomodoro.SessionManager session_manager,
                                                                      Pomodoro.TimeBlock      time_block)
        {
            // time_block.set_data<bool> ("ended", true);
        }

        // public void handle_timer_resolve_state (Pomodoro.Timer          timer,
        //                                         ref Pomodoro.TimerState state)
        // {
        //    // var current_time_block = (unowned Pomodoro.TimeBlock) state.user_data;
        // }

        public override void handle_timer_state_changed (Pomodoro.Timer      timer,
                                                         Pomodoro.TimerState current_state,
                                                         Pomodoro.TimerState previous_state)
        {
            var current_time_block = current_state.user_data as Pomodoro.TimeBlock;
            var skipped = timer.get_last_action () == Pomodoro.TimerAction.SKIP;

            current_time_block.set_data<bool> ("skipped", skipped);
        }

        public override void handle_timer_finished (Pomodoro.Timer      timer,
                                                    Pomodoro.TimerState state)
        {
            var current_time_block = state.user_data as Pomodoro.TimeBlock;
            var skipped = current_time_block.get_data<bool> ("skipped");
            var completed =
                current_time_block.duration > 0 &&
                !skipped;

            current_time_block.set_data<bool> ("completed", completed);
            current_time_block.set_data<bool> ("finished", true);
        }

        public override void handle_timer_suspended (Pomodoro.Timer timer,
                                                     int64          start_time,
                                                     int64          end_time)
        {
            // var current_time_block = timer.state.user_data as Pomodoro.TimeBlock;
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
         * Initialize a strategy for a session.
         *
         * It's called when:
         *  - session got created, but not started
         *  - when strategy gets changed
         */
        // public override void initialize (Pomodoro.Session session,
                                         // Pomodoro.SessionTemplate sesstion_template,
        //                                  int64            timestamp = -1)
        // {
        //     Pomodoro.ensure_timestamp (ref timestamp);
        //
        //     base.reschedule (session, timestamp);
        //
        ///    // TODO
        // }

        /**
         * Reschedules future blocks of a session
         */
        public override void reschedule (Pomodoro.Session session,
                                         // Pomodoro.SessionTemplate sesstion_template,
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
