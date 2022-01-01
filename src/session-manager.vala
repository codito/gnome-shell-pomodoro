namespace Pomodoro
{
    /**
     * SessionManager manages and advances time-blocks and sessions.
     */
    public class SessionManager : GLib.Object
    {
        private static unowned Pomodoro.SessionManager? instance = null;

        public Pomodoro.Timer timer { get; construct; }

        [CCode(notify = false)]
        public unowned Pomodoro.TimeBlock current_time_block {
            get {
                return this._current_time_block;
            }
            set {
                var previous_time_block = this._current_time_block;

                if (previous_time_block != value) {
                    this._current_time_block = value;

                    if (previous_time_block != null) {
                        this.leave_time_block (previous_time_block);
                    }

                    if (value != null && this._current_time_block == value) {
                        this.enter_time_block (value);
                    }
                }

                // var previous_time_block = this.timer.time_block;

                // unowned Pomodoro.Session? previous_session = previous_time_block != null
                //     ? previous_time_block.session
                //     : null;

                // if (previous_time_block != value) {
                //     this.timer.time_block = value;  // TODO: notify

                //     this.notify_property ("current-time-block");

                //     if (previous_session != value.session) {
                //         this.notify_property ("current-session");
                //     }
                // }
            }
        }

        [CCode(notify = false)]
        public unowned Pomodoro.Session current_session {
            get {
                return this._current_session;
                // return this.current_time_block.session;
            }
            set {
                assert_not_reached ();

                // var current_time_block = this._current_time_block;

                // if (value == null) {
                // }

                // if (this.current_time_block.session != value) {
                //     this.current_time_block = value.get_first_time_block ();  // TODO: create undefined time-block if null
                // }
            }
        }

        /**
         * Keep current session and time-block to track whether they have changed.
         * `Timer.time_block` keeps the master value.
         */
        private Pomodoro.TimeBlock? _current_time_block = null;
        private Pomodoro.Session? _current_session = null;
        private Pomodoro.State _current_state = Pomodoro.State.UNDEFINED;

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
            // TODO / FIXME instance and get_default both are unowned, is it ok?

            // if (Pomodoro.SessionManager.instance == null) {
            //     var session_manager = new Pomodoro.SessionManager ();
            //     session_manager.set_default ();
            // }

            return Pomodoro.SessionManager.instance;
        }

        public void set_default ()
        {
            Pomodoro.SessionManager.instance = this;

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

        public void advance (int64 timestamp = -1)
        {
            // TODO
        }

        public void advance_to (Pomodoro.State state,
                                int64          timestamp = -1)
        {
            // TODO
        }

        private Pomodoro.Session resolve_next_session ()
        {
            var next_session = new Pomodoro.Session ();

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

            var previous_state = this._current_state;

            if (time_block.state != previous_state) {
                this._current_state = time_block.state;

                this.state_changed (this._current_state, previous_state);
            }
        }

        public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        {
            // TODO: resolve next time_block and change current time_block

            var next_time_block = this.resolve_next_time_block ();

            this.current_session = next_time_block.session;
            this.current_time_block = next_time_block;
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
    }
}
