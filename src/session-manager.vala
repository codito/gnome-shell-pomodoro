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

        public Pomodoro.Timer timer { get; construct; }


        /**
         * A current session.
         *
         * Check whether session hasn't expired before use.
         *
         * Setter replaces current session with another one without adjusting either of them.
         * To correct the timing use `advance_*` methods. Setter is meant only for unit testing.
         */
         // * TODO: set current_time_block to null
         // * When setting a session, first time-block is selected and timer is started.
        [CCode(notify = false)]
        public unowned Pomodoro.Session current_session {
            get {
                return this._current_session;
            }
            set {
                if (this._current_session == value) {
                    return;
                }

                // var next_time_block = value != null ? value.get_first_time_block () : null;

                // if (next_time_block != null) {
                //     this.advance_to_time_block (next_time_block);
                // }
                // else {
                //     this.set_current_time_block_internal (value, null);
                // }

                // this.set_current_time_block_internal (
                //     value,
                //     value != null ? value.get_first_time_block () : null);

                this.set_current_time_block_internal (value, null);
            }
        }

        /**
         * Current time-block.
         *
         * Only `SessionManager` is aware which time-block is current. Current time-block is reflected in `Timer.state`,
         * but it's not 1:1 equivalent. Time-block has clearly defined gaps, while timer only keeps track of offset.
         *
         * `null` means that current time-block has not yet started and that timer is stopped.
         *
         * Setter replaces current time-block with another one without adjusting either of them.
         * To correct the timing use `advance_*` methods. Setter is meant only for unit testing.
         * Time-block must be assigned to a session beforehand. Setting a time-block with a different session will
         * also switch to a new session. All blocks within new session preceding given `time-block` will be removed.
         */
        [CCode(notify = false)]
        public unowned Pomodoro.TimeBlock current_time_block {
            get {
                return this._current_time_block;
            }
            set {
                if (value != null && value.session == null) {
                    GLib.debug ("Ignoring call to set SessionManager.current_time_block with a time-block that is not assigned to any session.");
                    return;
                }

                if (this._current_time_block == value) {
                    return;
                }

                this.set_current_time_block_internal (
                    value != null ? value.session : this._current_session,
                    value);
            }
        }

        private Pomodoro.Session?   _current_session = null;
        private Pomodoro.TimeBlock? _current_time_block = null;
        private bool                current_time_block_entered = false;
        private bool                current_session_entered = false;
        private Pomodoro.Session?   previous_session = null;
        private Pomodoro.TimeBlock? previous_time_block = null;
        private int                 timer_freeze_count = 0;
        // private Pomodoro.State      _current_state = Pomodoro.State.UNDEFINED;
        private ulong               timer_resolve_state_id = 0;
        private ulong               timer_state_changed_id = 0;
        private ulong               timer_suspended_id = 0;

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
            this.timer.reset ();

            this.timer_resolve_state_id = this.timer.resolve_state.connect (this.on_timer_resolve_state);
            this.timer_state_changed_id = this.timer.state_changed.connect (this.on_timer_state_changed);
            this.timer_suspended_id = this.timer.suspended.connect (this.on_timer_suspended);
        }

        private void set_current_time_block_internal (Pomodoro.Session?   session,
                                                      Pomodoro.TimeBlock? time_block)
        {
            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;

            // Leave previous session.
            if (previous_time_block != null)
            {
                if (this.current_time_block_entered) {
                    this.current_time_block_entered = false;  // TODO: place it inside handler
                    this.leave_time_block (previous_time_block);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    // a different time-block was set during `leave_time_block()` emission
                    return;
                }
            }

            // Leave previous time-block.
            if (previous_session != null && previous_session != session)
            {
                if (this.current_session_entered) {
                    this.current_session_entered = false;  // TODO: place it inside handler
                    this.leave_session (previous_session);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    // a different time-block was set during `leave_session()` emission
                    return;
                }
            }

            // Enter session.
            if (session != previous_session)
            {
                this._current_session = session;

                this.notify_property ("current-session");

                if (session != null) {
                    this.current_session_entered = true;  // TODO: place it inside handler
                    this.enter_session (session);
                }

                if (this._current_time_block != previous_time_block || this._current_session != session) {
                    // a different time-block was set during `enter_session()` emission
                    return;
                }
            }

            // Enter time-block. It will start or stop the timer depending whether thime-block is null.
            if (time_block != previous_time_block)
            {
                this.previous_session    = previous_session;
                this.previous_time_block = previous_time_block;
                this._current_time_block = time_block;

                this.notify_property ("current-time-block");

                if (time_block != null) {
                    // var timestamp = Pomodoro.Timestamp.from_now ();  // TODO: fetch from Timer.get_last_state_changed_time () ?

                    this.freeze_timer ();
                    timer.state = Pomodoro.TimerState () {
                        duration      = time_block.end_time - time_block.start_time,
                        offset        = time_block.calculate_elapsed (),  // TODO: specify timestamp
                        started_time  = time_block.start_time,
                        paused_time   = Pomodoro.Timestamp.UNDEFINED,
                        finished_time = Pomodoro.Timestamp.UNDEFINED,
                        user_data     = time_block
                    };
                    this.thaw_timer ();

                    this.current_time_block_entered = true;  // TODO: place it inside handler
                    this.enter_time_block (time_block);
                }
                else {
                    this.freeze_timer ();
                    this.timer.reset ();
                    this.thaw_timer ();
                }
            }
        }

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
            // TODO
        }


        private void freeze_timer ()
        {
            this.timer_freeze_count++;
        }

        private void thaw_timer ()
                                 ensures (this.timer_freeze_count >= 0)
        {
            this.timer_freeze_count--;
        }



        private Pomodoro.Session initialize_session (int64 timestamp)
        {
            // TODO: in future we may want to align time-blocks according to agenda/scheduled events

            return new Pomodoro.Session.from_template (Pomodoro.SessionTemplate (), timestamp);
        }

        private void initialize_timer_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            var current_time_block = this._current_time_block;

            // Adjust timer state acording to current-time-block.
            if (current_time_block != null) {
                state.duration     = current_time_block.end_time - current_time_block.start_time;
                state.offset       = current_time_block.calculate_elapsed (timestamp);
                state.started_time = current_time_block.start_time;
                state.user_data    = current_time_block;
            }
            else {
                state.user_data = null;
            }
        }


        private void reschedule (Pomodoro.Session session,
                                 int64            timestamp)
        {

        }

        private void mark_current_time_block_ended (int64 timestamp)
        {
            if (this._current_time_block == null) {
                return;
            }

            if (this._current_time_block.end_time > timestamp) {
                this._current_time_block.end_time = timestamp;
            }
        }

        private void mark_current_session_ended (int64 timestamp)
        {
            if (this._current_session == null || this._current_time_block == null) {
                return;
            }

            // if (this._current_session == this._current_time_block.session) {
            this._current_session.remove_after (this._current_time_block);
            // }

            this.mark_current_time_block_ended (timestamp);
        }

        private void extend_current_time_block (int64 timestamp)
        {
            var time_block = this._current_time_block;
            if (time_block == null) {
                return;
            }

            var state_duration = time_block.state.get_default_duration ();  // TODO: handle long break

            // session.freeze_changed ();
            if (time_block.end_time < timestamp) {
                var gap = new Pomodoro.Gap.with_start_time (time_block.end_time, timestamp);

                time_block.end_time = timestamp + state_duration;
                time_block.add_gap (gap);
            }
            else {
                time_block.end_time += state_duration - time_block.calculate_remaining (timestamp);
            }

            // this.reschedule (time_block.session, timestamp);

            time_block.session.align_after (time_block);
            // time_block.session.thaw_changed ();
        }

        /**
         * It's similar to `set_current_time_block_internal`, but also modifies current time-block end-time and
         * shifts given `time_block` to `timestamp`.
         * When it modifies given time-bloc it tries to preserve its duration.
         */
        public void advance_to_time_block (Pomodoro.TimeBlock? time_block,
                                           int64               timestamp = -1)
        {
            var session = time_block != null ? time_block.session : this._current_session;

            Pomodoro.ensure_timestamp (ref timestamp);

            if (time_block == null) {
                this.mark_current_time_block_ended (timestamp);
            }
            else if (session != this._current_session) {
                this.mark_current_session_ended (timestamp);
            }
            else if (time_block == this._current_time_block) {  // && !time_block.has_ended (timestamp)) {
                this.extend_current_time_block (timestamp);
            }
            else {
                this.mark_current_time_block_ended (timestamp);
                // this.align_after (this._current_time_block);

                while (true)
                {
                    var next_time_block = session.get_next_time_block (this._current_time_block);

                    if (next_time_block == null) {
                        // Selected time-block was in the past, duplicate it.
                        next_time_block = new Pomodoro.TimeBlock (time_block.state);
                        next_time_block.set_time_range (time_block.start_time, time_block.end_time);
                        session.append (next_time_block);

                        time_block = next_time_block;
                        break;
                    }

                    if (next_time_block != time_block) {
                        session.remove (next_time_block);
                    }
                }

                // session.freeze_changed ();
                // session.thaw_changed ();
            }

            if (time_block != null) {
                session.align_after (time_block);

                // TODO:
                //  - realign future time-blocks according to calendar
                //  - add/remove time-blocks according to work/break ratio
            }

            this.set_current_time_block_internal (session, time_block);
        }

        public void advance_to_state (Pomodoro.State state,
                                      int64          timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (state == Pomodoro.State.UNDEFINED) {
                this.advance_to_time_block (null, timestamp);
                return;
            }

            // Extend current time-block.
            if (this._current_time_block != null &&
                this._current_time_block.state == state)
            {
                // TODO: check if session has expired
                // if (this.timer.state.user_data == this._current_time_block)
                // !this._current_session.is_expired (timestamp)

                // TODO: extend block
                this.advance_to_time_block (this._current_time_block, timestamp);
                return;
            }

            // Extend previous time-block.
            // if (this._current_time_block == null &&
            //     this.previous_time_block != null &&
            //     this.previous_time_block.session == this._current_session &&
            //     this.previous_time_block.state == state &&
            //     )
            // {
            //     // TODO: extend block
            //     this.advance_to_time_block (this.previous_time_block, timestamp);
            //     return;
            // }

            // Select upcoming state.
            var next_time_block = this._current_session != null
                ? this._current_session.get_next_time_block (this._current_time_block)
                : null;
            var next_session = next_time_block != null ? next_time_block.session : null;

            if (next_session == null || next_session.is_expired (timestamp)) {
                next_session = this.initialize_session (timestamp);
                next_time_block = next_session.get_first_time_block ();
            }

            if (next_time_block == null) {
                assert_not_reached ();
                // TODO append to next_session
                // TODO: figure out next time-block duration
                // next_time_block = new Pomodoro.TimeBlock.with_start_time (state, timestamp);
                // next_session.append (next_time_block);
            }

            // Insert a break at the beggining of session if requested
            if (next_time_block.state != state) {
                assert_not_reached ();
                // var tmp = next_time_block;
                // next_time_block = new Pomodoro.TimeBlock.with_start_time (state, timestamp);
                // TODO: figure out next duration
                // TODO: use insert sorted?
                // next_session.insert_before (next_time_block, tmp);
            }

            this.advance_to_time_block (next_time_block, timestamp);
        }

        public void advance (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var next_time_block = this._current_session != null
                ? this._current_session.get_next_time_block (this._current_time_block)
                : null;
            var next_session = next_time_block != null ? next_time_block.session : null;

            if (next_session == null || next_session.is_expired (timestamp)) {
                next_session = this.initialize_session (timestamp);
                next_time_block = next_session.get_first_time_block ();
            }

            if (next_time_block == null) {
                assert_not_reached ();
                // TODO: figure out next time-block state / duration
                // next_time_block = new Pomodoro.TimeBlock.with_start_time (state, timestamp);
                // next_session.append (next_time_block);
            }

            this.advance_to_time_block (next_time_block, timestamp);
        }




        private void on_timer_resolve_state (ref Pomodoro.TimerState state)
        {
            debug ("on_timer_resolve_state");

            var timestamp = this.timer.get_last_state_changed_time ();

            if (this.timer_freeze_count > 0) {
                debug ("on_timer_resolve_state: A");
                return;
            }

            // Timer is paused or has finished. Nothing to resolve.
            // Advancing to a next time-block should be done after emitting `Timer.state_changed`.
            if (state.finished_time >= 0 || state.paused_time >= 0) {
                debug ("on_timer_resolve_state: B");
                return;
            }

            // Stopping (resetting) the timer.
            // Adjust state as if the timer has already stopped. Handling will be continued in `Timer.state_changed`.
            if (state.started_time < 0) {
                debug ("on_timer_resolve_state: C");
                state.user_data = null;
                return;
            }

            // Timer is started by a session manager.
            if (state.started_time >= 0 && state.user_data == this._current_time_block && this._current_time_block != null) {  //  && this.current_time_block_entered
                debug ("on_timer_resolve_state: D");
                return;
            }

            // Starting the timer. Handle expired session.
            if (this._current_session != null && this._current_session.is_expired (timestamp))
            {
                debug ("on_timer_resolve_state: E");
                // TODO: are timestamps correct here?
                // var next_session = this.initialize_session (state.started_time);
                // var next_time_block = current_session.get_first_time_block ();

                // this.advance_to_time_block (next_time_block, state.started_time);

                this.advance (state.started_time);

                this.initialize_timer_state (ref state, timestamp);
                return;
            }

            // Starting the timer.
            if (this._current_time_block == null) {  // || !this.current_time_block_entered
                debug ("on_timer_resolve_state: F");
                this.advance_to_state (Pomodoro.State.POMODORO, state.started_time);

                this.initialize_timer_state (ref state, timestamp);
                return;
            }

             assert (state.user_data == this._current_time_block);
             assert (this.current_time_block_entered == (this._current_time_block != null));
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            debug ("on_timer_state_changed");

            var timestamp = this.timer.get_last_state_changed_time ();

            if (this.timer_freeze_count > 0) {
                debug ("on_timer_state_changed: A");
                return;
            }

            // Stopped current time-block
            if (current_state.user_data == null && this._current_time_block != null) {
                debug ("on_timer_state_changed: B");
                // TODO: use previous_state.finished_time as timestamp
                this.advance_to_time_block (null, timestamp);
                return;
            }

            // Advance to next time-block
            if (current_state.finished_time >= 0 && this._current_time_block != null) {
                debug ("on_timer_state_changed: C");
                // TODO: pause state and wait for user activity

                this.advance (current_state.finished_time);
                return;
            }


        /*  TODO
            // TODO these are very similar, likely needs a refactor:
            //   - prepare_current_time_block
            //   - advance_to

            // Advance to next time-block
            if (current_state.finished_time >= 0) {
                this.advance (current_state.finished_time);
                return;
            }

            // Stopped current time-block
            if (current_state.started_time < 0) {
                this.advance_to (null, timestamp);
                return;
            }

            // Start next time-block
            if (current_state.user_data != this._current_time_block) {
                // TODO: register pauses
                return;
            }
        */


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




        public signal void enter_session (Pomodoro.Session session)
        {
            // TODO: monitor for session changes
        }

        public signal void leave_session (Pomodoro.Session session)
        {
            // TODO disconnect session signals
        }

        public signal void enter_time_block (Pomodoro.TimeBlock time_block)
        {
            // TODO: monitor for time-block changes
        }

        public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        {
            // TODO disconnect time_block signals
        }

        public signal void state_changed (Pomodoro.State current_state,
                                          Pomodoro.State previous_state);

        public override void dispose ()
        {
            if (Pomodoro.SessionManager.instance == null) {
                Pomodoro.SessionManager.instance = null;
            }

            if (this.timer_resolve_state_id != 0) {
                this.timer.disconnect (this.timer_resolve_state_id);
                this.timer_resolve_state_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            if (this.timer_suspended_id != 0) {
                this.timer.disconnect (this.timer_suspended_id);
                this.timer_suspended_id = 0;
            }

            base.dispose ();
        }
    }


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

}
