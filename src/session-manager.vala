namespace Pomodoro
{
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


    /**
     * SessionManager manages and advances time-blocks and sessions.
     */
    public class SessionManager : GLib.Object
    {
        private static Pomodoro.SessionManager? instance = null;

        private delegate void TimerContextFunc (Pomodoro.Timer timer);


        public Pomodoro.Timer timer { get; construct; }

        [CCode(notify = false)]
        public unowned Pomodoro.Session current_session {
            get {
                return this._current_session;
            }
            set {
                this.set_current_time_block_full (value,
                                                  value != null ? value.get_first_time_block () : null);
            }
        }

        [CCode(notify = false)]
        public unowned Pomodoro.TimeBlock current_time_block {
            get {
                return this._current_time_block;
            }
            set {
                this.set_current_time_block_full (value != null ? value.session : this._current_session,
                                                  value);
            }
        }

        /**
         * Keep current session and time-block to track whether they have changed.
         * `Timer.time_block` keeps the master value.
         */
        private Pomodoro.TimeBlock? _current_time_block = null;
        private Pomodoro.Session?   _current_session = null;
        private Pomodoro.State      _current_state = Pomodoro.State.UNDEFINED;
        private int                 block_timer_signal_handlers_count = 0;

        public SessionManager ()
        {
            GLib.Object (
                timer: Pomodoro.Timer.get_default ()
            );
        }

        public SessionManager.with_timer (Pomodoro.Timer timer)
        {
            GLib.Object (
                timer: timer
            );
        }

        construct
        {
            // this.timer.notify["time-block"].connect (this.on_timer_time_block_notify);

            // this.on_timer_time_block_notify ();

            // Setup timer
            this.timer.reset ();

            // TODO: restore session


            // TODO: connect timer signals

            this.timer.resolve_state.connect (this.on_timer_resolve_state);
            this.timer.state_changed.connect (this.on_timer_state_changed);
            this.timer.state_changed.connect_after (this.on_timer_state_changed_after);
            this.timer.suspended.connect (this.on_timer_suspended);
        }

        ~SessionManager ()
        {
            if (Pomodoro.SessionManager.instance == null) {
                Pomodoro.SessionManager.instance = null;
            }

            // this.timer.notify["time-block"].disconnect (this.on_timer_time_block_notify);
        }

        // construct
        // {
        //     this.timer = Pomodoro.Timer.get_default ();
        // }

        public static unowned Pomodoro.SessionManager? get_default ()
        {
            if (Pomodoro.SessionManager.instance == null) {
                var session_manager = new Pomodoro.SessionManager ();
                session_manager.set_default ();
            }

            return Pomodoro.SessionManager.instance;
        }

        public void set_default ()
        {
            Pomodoro.SessionManager.instance = this;

            // TODO: connect to Application to cleanup at exit

            // this.watch_closure (() => {
            //     if (Pomodoro.SessionManager.instance == session_manager) {
            //         Pomodoro.SessionManager.instance = null;
            //     }
            // });
        }




        public void reset (int64 timestamp = -1)
        {
            // TODO
        }

        // public void advance (int64 timestamp = -1)
        // {
            // TODO
        // }

        // public void advance_to (Pomodoro.State state,
        //                         int64          timestamp = -1)
        // {
            // TODO
        // }

        private Pomodoro.Session resolve_next_session ()
        {
            var next_session = new Pomodoro.Session.from_template ();

            // TODO: schedule time blocks

            return next_session;
        }

        /**
         * Resolve next states after timer elapse or state change.
         *
         * Return true if state has been changed.
         */
        private Pomodoro.TimeBlock resolve_next_time_block ()
        {
            // TODO: pick scheduled or create new time_block

            // var current_time_block = this.current_time_block;
            var next_time_block = this.current_session != null
                ? this.current_session.get_next_time_block (this.current_time_block)
                : null;

            if (next_time_block == null) {
                // var next_state = current_time_block != null ?

                var next_session = this.resolve_next_session ();
                next_time_block = next_session.get_first_time_block ();
            }

            return next_time_block;

            /*
            var original_state = this.internal_state;
            var state_changed = false;

            while (this.internal_state.duration > 0.0 &&
                   this.internal_state.is_completed ())
            {
                this.state_leave (this.internal_state);

                this.internal_state = this.internal_state.create_next_state (this.score, this.timestamp);
                this.update_offset ();

                state_changed = true;

                this.state_enter (this.internal_state);
            }

            if (state_changed) {
                this.state_changed (this.internal_state, original_state);
            }

            return state_changed;
            */
        }

        // TODO: store as json or in db?
        /**
         * Saves session state to db.
         *
         * TODO also store snapshot timestamp whether timer is paused
         *
         * TODO: should be async
         */
        public void save (int64 timestamp = Pomodoro.get_current_time ())
        {
            // TODO

            // var timer_datetime = new DateTime.from_unix_utc (
            //                      (int64) Math.floor (this.timestamp));

            // var state_datetime = new DateTime.from_unix_utc (
            //                      (int64) Math.floor (this.state.timestamp));

            // settings.set_string ("timer-state",
            //                      this.state.name);
            // settings.set_double ("timer-state-duration",
            //                      this.state.duration);
            // settings.set_string ("timer-state-date",
            //                      state_datetime.to_string ());
            // settings.set_double ("timer-elapsed",
            //                      this.state.elapsed);
            // settings.set_double ("timer-score",
            //                      this.score);
            // settings.set_string ("timer-date",
            //                      timer_datetime.to_string ());
            // settings.set_boolean ("timer-paused",
            //                       this.is_paused);
        }

        public async void save_async () throws GLib.Error
        {
            // TODO

            this.save ();
        }

        public async void restore_async () throws GLib.Error
        {
            // TODO

            this.restore ();
        }

        /**
         * Restores session state from db.
         *
         * When restoring, lost time is considered as pause.
         *
         * TODO: should be async
         */
        public void restore ()
        {
            // var state          = Pomodoro.TimerState.lookup (settings.get_string ("timer-state"));
            // var is_paused      = settings.get_boolean ("timer-paused");
            // var score          = settings.get_double ("timer-score");
            // var last_timestamp = 0.0;
            // var int64 timestamp = Pomodoro.get_current_time ();

            // if (state != null)
            // {
            //     state.duration = settings.get_double ("timer-state-duration");
            //     state.elapsed  = settings.get_double ("timer-elapsed");

            //     var state_datetime = new DateTime.from_iso8601 (
            //                        settings.get_string ("timer-state-date"), new TimeZone.local ());

            //     var last_datetime = new DateTime.from_iso8601 (
            //                        settings.get_string ("timer-date"), new TimeZone.local ());

            //     if (state_datetime != null && last_datetime != null) {
            //         state.timestamp = (double) state_datetime.to_unix ();
            //         last_timestamp = (double) last_datetime.to_unix ();
            //     }
            //     else {
            //         /* In case there is no valid state-date, elapsed time
            //          * will be lost.
            //          */
            //         state = null;
            //     }
            // }

            // if (state != null && timestamp - last_timestamp < TIME_TO_RESET_SCORE)
            // {
            //     this.freeze_notify ();
            //     this.score = score;
            //     this.set_state_full (state, last_timestamp);
            //     this.pause (last_timestamp);
            //     this.thaw_notify ();

            //     this.update (timestamp);

            //     if (is_paused) {
            //         this.notify_property ("is-paused");
            //     }
            //     else {
            //         this.resume (timestamp);
            //     }
            // }
            // else {
            //     this.reset (timestamp);
            // }
        }

        public void destroy ()
        {

        }

        public override void dispose ()
        {
            // TODO: disconnect Timer signals

            base.dispose ();
        }

        public signal void enter_session (Pomodoro.Session session)
        {
            // TODO: set session as current
        }

        public signal void leave_session (Pomodoro.Session session)
        {
            // TODO: resolve next session and change current session
        }

        public signal void enter_time_block (Pomodoro.TimeBlock time_block)
        {
            // time_block.changed.connect ();  // TODO: monitor time-block changes

            // TODO: set timer state
            // this.timer.time_block = value;

            // var previous_state = this._current_state;

            // if (time_block.state != previous_state) {
            //     this._current_state = time_block.state;

            //     this.state_changed (this._current_state, previous_state);
            // }
        }

        public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        {
            // TODO: resolve next time_block and change current time_block

            // var next_time_block = this.resolve_next_time_block ();

            // this._current_session = next_time_block.session;
            // this._current_time_block = next_time_block;
        }

        public signal void state_changed (Pomodoro.State current_state,
                                          Pomodoro.State previous_state);

        // private void on_timer_time_block_notify ()
        // {
            // TODO: warn if time_block was changed through

            // var previous_time_block = this._current_time_block;
            // var previous_session = this._current_session;

            // print ("# A\n");

            // this._current_time_block = this.timer.time_block;

            // print ("# B\n");

            // this._current_session = current_time_block != null ? current_time_block.session : null;

            // print ("# C\n");

            // if (this._current_time_block != previous_time_block) {
            //     this.notify_property ("current-time-block");
            // }

            // if (this._current_session != previous_session) {
            //     this.notify_property ("current-session");
            // }
        // }


        // public void mark_current_time_block_start (int64 timestamp)
        // {
        //     if (this._current_time_block == null) {
        //         // Initialize session and pick first time-block
        //         if (this._current_session == null) {
        //             this._current_session = new Pomodoro.Session.from_template (timestamp);
        //         }
        //
        //         this._current_time_block = this._current_session.get_first_time_block ();
        //     }
        //     else {
        //         this._current_session.
        //     }
        //
        //     this._current_time_block.end_time = timestamp;
        //     this._current_time_block = null;
        // }


        // public void mark_current_time_block_end (int64 timestamp)
        // {
        //     if (this._current_time_block == null) {
        //         return;
        //     }
        //
        //     this._current_time_block.end_time = timestamp;
        //     this._current_time_block = null;
        // }


        /**
         * Determine whether to start a new session or continue current one.
         */
        // private void resolve_current_session (int64 timestamp)
        // {
        //     var current_session = this._current_session;

        //     if (current_session == null || !can_continue_current_session (timestamp)) {
        //         current_session = new Pomodoro.Session.from_template (timestamp);
        //     }
        //     else {
                // TODO: check if we can attach time-block to current session, or start a new one
        //     }

        //     if (this._current_session != null) {
        //         this._current_session.finish (timestamp);
        //     }

        //     this._current_session = current_session;

        //     this.resolve_current_time_block (state.started_time);
        // }

        /**
         * Determine current time-block within current session.
         */
        // private void resolve_current_time_block (int64 timestamp)
        // {
        //     var current_session = this._current_session;
        //     var current_time_block = this._current_time_block;

        //     if (current_time_block != null &&
        //         current_time_block.session == current_session)
        //     {
        //         current_time_block = current_session.get_next_time_block (this.current_time_block);
        //     }
        //     else {
        //         current_time_block = current_session.get_first_time_block ();
        //     }

        //     if (this._current_time_block != current_time_block) {
        //         current_session.reschedule (current_time_block, timestamp);

        //         this._current_time_block = current_time_block;
        //     }
        // }



        private void block_timer_signal_handlers (TimerContextFunc func)
                                                  ensures (this.block_timer_signal_handlers_count >= 0)
        {
            this.block_timer_signal_handlers_count++;

            // TODO: we could block handlers https://valadoc.org/gobject-2.0/GLib.SignalHandler.html

            func (this.timer);

            this.block_timer_signal_handlers_count--;
        }


        private bool has_pending_enter_session_signal = false;
        private bool has_pending_enter_time_block_signal = false;


        private void set_current_time_block_full (Pomodoro.Session?   session,
                                                  Pomodoro.TimeBlock? time_block)
        {
            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;

            if (previous_time_block != null && time_block != previous_time_block) {
                this.leave_time_block (previous_time_block);
            }

            if (previous_session != null && session != previous_session) {
                this.leave_session (previous_session);
            }

            this._current_session = session;
            this._current_time_block = time_block;

            if (session != previous_session) {
                this.notify_property ("current-session");
            }

            if (time_block != previous_time_block) {
                this.notify_property ("current-time-block");
            }

            // if (session != null && session != previous_session) {
            //     this.enter_session (session);
            // }

            // if (time_block != null && time_block != previous_time_block) {
            //     this.enter_time_block (time_block);
            // }

            if (session != null && session != previous_session) {
                this.has_pending_enter_session_signal = true;
            }

            if (time_block != null && time_block != previous_time_block) {
                this.has_pending_enter_time_block_signal = true;
            }
        }

        /**
         * Either pick scheduled block as current or initialize new session.
         */
        private void prepare_current_time_block (Pomodoro.State state,
                                                 int64          start_time)
                                                 ensures (this._current_session != null &&
                                                          this._current_time_block != null)
        {
            var session = this._current_session;
            var time_block = this._current_time_block;

            // Check if session hasn't expired. Create a new session if necessary.
            if (session != null && session.is_expired (start_time)) {
                session = null;
                time_block = null;
            }

            if (time_block != null && time_block.state == state) {
                // TODO extend current time-block, so that remaining time is 25 minutes
                assert_not_reached ();
                // TODO: return;
            }

            // Try to pick next POMODORO within session
            if (session == null) {
                session = new Pomodoro.Session.from_template (start_time);
                time_block = session.get_first_time_block ();
                // time_block = session.find_time_block (state, time_block);  // TODO
            }
            else {
                // TODO: Check if session can be completed,
                //       eg if we force POMODORO during a long break, it should start new session

                // TODO select next POMODORO from session, remove time_blocks between current_time_block and chosen one
                assert_not_reached ();
                // this.time_blocks.find (time_block);
            }

            // Append new POMODORO if there there is none scheduled
            if (time_block == null) {
                time_block = new Pomodoro.TimeBlock.with_start_time (state, start_time);

                session.insert_after (time_block, this._current_time_block);
            }

            if (this._current_time_block != null) {
                this._current_time_block.end_time = int64.min (this._current_time_block.end_time,
                                                               time_block.start_time);
            }

            this.set_current_time_block_full (session, time_block);
        }

        // public void start_pomodoro (int64 start_time)
        //                              ensures (this._current_session != null && this._current_time_block != null)
        // {
        //     this.block_timer_signal_handlers ((timer) => {
        //         timer.reset (time_block.duration, time_block);
        //         timer.start (time_block.start_time);
        //     });
        // }

        private void on_timer_resolve_state (ref Pomodoro.TimerState state)
        {
            if (this.block_timer_signal_handlers_count > 0) {
                return;
            }

            // print ("\n@@@@ resolve state: %s\n", state.to_representation ());

            // var timestamp = this.timer.get_last_state_changed_time ();
            // var current_session = this._current_session;
            // var current_time_block = this._current_time_block;

            // Stopping the timer.
            if (state.started_time < 0) {
                state.user_data = null;
                return;
            }

            // Starting timer. Check if need to initialize a new session or a time-block.
            if (state.started_time >= 0 &&
                state.user_data == null
                // (state.user_data == null || state.user_data != this._current_time_block)  // TODO?
            ) {
                this.prepare_current_time_block (Pomodoro.State.POMODORO, state.started_time);

                state.duration = this._current_time_block.duration;  // TODO: Should not count gap times. At this point time-block should not have any gaps.
                state.user_data = this._current_time_block;
                return;
            }

            // TODO: Advance to a next time-block
            // if (state.started_time >= 0) {
                // this.resolve_current_session (timestamp);
                // this.resolve_current_time_block (state.started_time);

            //     state.duration = this.current_time_block.calculate_duration ();
            //     state.user_data = this.current_time_block;
            //     return state;
            // }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this.block_timer_signal_handlers_count > 0) {
                // TODO: emit leave_time_block and enter_time_block
                return;
            }

            var timestamp = this.timer.get_last_state_changed_time ();

            // Stopped current time-block
            if (current_state.started_time < 0) {
                // this.mark_current_time_block_end (timestamp);
                return;
            }

            // Start next time-block
            if (current_state.user_data != this._current_time_block) {
                // TODO: register pauses
                return;
            }

            // TODO: emit leave_time_block and enter_time_block

            // this.mark_current_time_block_end (timestamp);
            // advance to next block

            // this.mark_current_time_block_start (timestamp);

            // if (this.ignore_timer_state_change) {
            //     return;
            // }

            // if (current_state.finished_time >= 0) {
            //     this.timer.state = this.resolve_next_timer_state ();
            // }

            // Advancing states
            // if (current_state.user_data != this._current_time_block) {
            //     if (this._current_session == null) {
            //         this._current_session = new Pomodoro.Session.from_template (state.start_time);
            //     }
            // }
        }

        private void on_timer_state_changed_after (Pomodoro.TimerState current_state,
                                                   Pomodoro.TimerState previous_state)
        {
            var has_pending_enter_session_signal = this.has_pending_enter_session_signal;
            var has_pending_enter_time_block_signal = this.has_pending_enter_time_block_signal;
            var current_session = this._current_session;
            var current_time_block = this._current_time_block;

            if (has_pending_enter_session_signal && current_session != null) {
                this.has_pending_enter_session_signal = false;
                this.enter_session (current_session);
            }

            if (has_pending_enter_time_block_signal && current_time_block != null && current_time_block == this._current_time_block) {
                this.has_pending_enter_time_block_signal = false;
                this.enter_time_block (current_time_block);
            }
        }

        private void on_timer_suspended (int64 start_time,
                                         int64 end_time)
        {
            if (this._current_time_block == null) {
                return;
            }

            // var root_time_block = this._current_time_block.get_root ();

            // TODO: mark that time-block is due to system-suspend?
            // var pause_time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            // pause_time_block.set_time_range (start_time, end_time);

            // root_time_block.add_child (pause_time_block);

            // TODO: emit enter
            // TODO: set current time block
            // TODO: emit leave event
            // TODO: set back parent block, or next if reached
        }
    }
}
