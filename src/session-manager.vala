using GLib;


namespace Pomodoro
{
    /**
     * SessionManager manages and advances time-blocks and sessions.
     */
    public class SessionManager : GLib.Object
    {
        /**
         * Idle time after which session should no longer be continued, and new session should be created.
         */
        public const int64 SESSION_EXPIRY_TIMEOUT = Pomodoro.Interval.HOUR;

        private static Pomodoro.SessionManager? instance = null;

        public Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            construct {
                this._timer = value;
                this._timer.reset ();

                this.timer_resolve_state_id = this._timer.resolve_state.connect (this.on_timer_resolve_state);
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
                this.timer_finished_id = this._timer.finished.connect (this.on_timer_finished);
            }
        }

        [CCode(notify = false)]
        public Pomodoro.Scheduler scheduler {
            get {
                return this._scheduler;
            }
            set {
                if (this._scheduler == value) {
                    return;
                }

                this._scheduler = value;

                if (this._current_session != null && this._scheduler != null) {
                    this._scheduler.reschedule (this._current_session);
                }

                this.notify_property ("scheduler");
            }
        }

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

        private Pomodoro.Timer                   _timer;
        private Pomodoro.Scheduler               _scheduler;
        private Pomodoro.Session?                _current_session = null;
        private Pomodoro.TimeBlock?              _current_time_block = null;
        private bool                             current_time_block_entered = false;
        private ulong                            current_time_block_changed_id = 0;
        private bool                             current_session_entered = false;
        private Pomodoro.Session?                previous_session = null;
        private Pomodoro.TimeBlock?              previous_time_block = null;
        private GLib.Settings                    settings;
        private int                              resolving_timer_state = 0;
        private int                              timer_freeze_count = 0;
        private ulong                            timer_resolve_state_id = 0;
        private ulong                            timer_state_changed_id = 0;
        private ulong                            timer_suspended_id = 0;
        private ulong                            timer_finished_id = 0;

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
            this.settings = Pomodoro.get_settings ();
            this._scheduler = new Pomodoro.StrictScheduler ();

            // TODO: monitor settings and update session-template

            this.settings.changed.connect (this.on_settings_changed);

            this.update_session_template ();
        }

        private void update_session_template ()
        {
            var pomodoro_duration = this.settings.get_uint ("pomodoro-duration");
            var short_break_duration = this.settings.get_uint ("short-break-duration");
            var long_break_duration = this.settings.get_uint ("long-break-duration");
            var cycles = this.settings.get_uint ("pomodoros-per-session");

            this._scheduler.session_template = Pomodoro.SessionTemplate () {
                pomodoro_duration = Pomodoro.Timestamp.from_seconds_uint (pomodoro_duration),
                short_break_duration = Pomodoro.Timestamp.from_seconds_uint (short_break_duration),
                long_break_duration = Pomodoro.Timestamp.from_seconds_uint (long_break_duration),
                cycles = cycles
            };
        }

        private void update_timer_state (int64 timestamp)
        {
            debug ("####### update_timer_state(): %lld", timestamp);

            var time_block = this._current_time_block;

            if (this.resolving_timer_state != 0) {
                GLib.debug ("#### Ignoring update_timer_state() as timer-state is still resolving");
                return;
            }

            this.freeze_timer ();

            if (time_block != null) {
                this._timer.state = Pomodoro.TimerState () {  // FIXME when resolving the state, we want to propagate this through call stack
                    duration      = time_block.end_time - time_block.start_time,
                    offset        = time_block.calculate_elapsed (timestamp),
                    started_time  = time_block.start_time,
                    paused_time   = Pomodoro.Timestamp.UNDEFINED,  // TODO: when advancing to a new state, we may pause the timer
                    finished_time = Pomodoro.Timestamp.UNDEFINED,
                    user_data     = time_block
                };
            }
            else {
                this._timer.reset ();
            }

            this.thaw_timer ();
        }

        private void set_current_time_block_internal (Pomodoro.Session?   session,
                                                      Pomodoro.TimeBlock? time_block,
                                                      int64               timestamp = -1)
        {
            if (Pomodoro.Timestamp.is_undefined (timestamp)) {
                timestamp = this._timer.get_last_state_changed_time ();  // TODO: is this correct?
            }

            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;

            if (time_block != null) {
                assert (session == time_block.session);

                debug("set_current_time_block_internal: %d", time_block.session.index(time_block));
            }

            // Leave previous session.
            if (previous_time_block != null)
            {
                // if (previous_time_block != null) {
                    // TODO: make a method TimeBlock.trim() ?
                //     debug ("trim previous_time_block");
                //     previous_time_block.end_time = timestamp;
                // }

                if (this.current_time_block_entered) {
                    // var session      = time_block.session;
                    // var timestamp    = this.timer.state.finished_time > 0 ? this.timer.state.finished_time : time_block.end_time; // TODO: is it correct?
                    var has_finished = (this.timer.user_data == time_block) && this.timer.is_finished ();  // TODO: to test
                    // TODO ask scheduler
                    var completed = true;
                    // var completed    = time_block.is_completed (has_finished, this.strictness, timestamp);

                    // TODO
                    // session.mark_time_block_ended (time_block, completed, timestamp);  // TODO: should be in resolve state
                    // session.reschedule (this._session_template, this.strictness, timestamp);

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
                    this.enter_session (session);
                }

                if (this._current_time_block != previous_time_block || this._current_session != session) {
                    GLib.debug ("A different time-block was set during `enter-session` emission.");
                    return;
                }
            }

            // Enter time-block. It will start or stop the timer depending whether time-block is null.
            if (time_block != previous_time_block)
            {
                this.previous_session    = previous_session;
                this.previous_time_block = previous_time_block;
                this._current_time_block = time_block;
                this.notify_property ("current-time-block");

                if (time_block != null) {
                    this.enter_time_block (time_block);
                }

                this.update_timer_state (timestamp);

                this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: bump session expiry on every timer state change?
            }
        }

        private unowned Pomodoro.TimeBlock? get_next_time_block ()
        {
            if (this._current_session == null) {
                debug ("get_next_time_block(): null");
                return null;
            }

            if (this._current_time_block == null)
            {
                if (this.previous_time_block != null &&
                    this.previous_session == this._current_session)
                {
                    debug ("get_next_time_block(): next to previous");
                    return this._current_session.get_next_time_block (this.previous_time_block);
                }
                else {
                    debug ("get_next_time_block(): first");
                    return this._current_session.get_first_time_block ();
                }
            }

            debug ("get_next_time_block(): %d", this._current_session.index (this._current_time_block));

            return this._current_session.get_next_time_block (this._current_time_block);
        }

        /**
         * Sets a default `SessionManager`.
         *
         * The old default manager is unreffed and the new manager referenced.
         *
         * A value of null for this will cause the current default manager to be released and a new default manager
         * to be created on demand.
         */
        public static void set_default (Pomodoro.SessionManager? session_manager)
        {
            Pomodoro.SessionManager.instance = session_manager;
        }

        /**
         * Return a default manager.
         *
         * A new default manager will be created on demand.
         */
        public static unowned Pomodoro.SessionManager get_default ()
        {
            if (Pomodoro.SessionManager.instance == null) {
                Pomodoro.SessionManager.set_default (new Pomodoro.SessionManager ());
            }

            return Pomodoro.SessionManager.instance;
        }

        // public unowned Pomodoro.TimeBlock? get_current_or_previous_time_block ()
        // {
        //     return this._current_time_block != null
        //         ? this._current_time_block
        //         : this.previous_time_block;
        // }

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
            debug ("SessionManager.initialize_session");

            var session = new Pomodoro.Session ();

            this._scheduler.reschedule (session, timestamp);

            return session;
        }

        private void initialize_timer_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            debug ("SessionManager.initialize_timer_state");

            var current_time_block = this._current_time_block;

            // Adjust timer state according to current-time-block.
            if (current_time_block != null) {
                debug ("current_time_block = %s", current_time_block.state.to_string ());

                state.duration     = current_time_block.end_time - current_time_block.start_time;
                state.offset       = current_time_block.calculate_elapsed (timestamp);
                state.started_time = current_time_block.start_time;
                state.user_data    = current_time_block;
            }
            else {
                state.user_data = null;
            }

            debug ("%s", state.to_representation ());
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

            // TODO: TimeBlock.changed event handler should do the reschedule
            // this.reschedule (time_block.session, timestamp);

            // time_block.session.align_after (time_block);
            // time_block.session.thaw_changed ();
            this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: also, should be called on timeblock change
        }

        private void mark_time_block_end (Pomodoro.TimeBlock time_block,
                                          int64              timestamp)
        {
            assert (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);

            // TODO: move this to leave-time-block signal handler?
            var has_finished = (
                this.timer.state.user_data == time_block &&
                this.timer.state.finished_time > 0
            );
            var has_completed = this._scheduler.is_time_block_completed (
                time_block,
                time_block.get_meta (),
                has_finished ? this.timer.state.finished_time : timestamp
            );

            time_block.set_status (has_completed
                                   ? Pomodoro.TimeBlockStatus.COMPLETED
                                   : Pomodoro.TimeBlockStatus.UNCOMPLETED);
            time_block.end_time = timestamp;
        }

        /**
         * Start given time-block
         *
         * While `set_current_time_block_internal` only marks which time-block and session is current,
         * advance_* methods modify session and time-blocks:
         *   - time-block is shifted to `timestamp`
         *   - session is adjusted accordingly
         */
        private void advance_to_time_block (Pomodoro.TimeBlock? time_block,
                                            int64               timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var session = time_block != null ? time_block.session : this._current_session;

            if (time_block != null) {  // TODO: remove
                debug("advance_to_time_block: %d", time_block.session.index (time_block));
            }

            if (time_block != null && time_block == this._current_time_block && !time_block.has_ended (timestamp)) {
                debug("advance_to_time_block: extend_current_time_block");
                this.extend_current_time_block (timestamp);
                // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: is it the best place to do bump expiry-time?
                // TODO: ensure we schedule following blocks
                return;
            }

            if (this._current_time_block != null) {
                this.mark_time_block_end (this._current_time_block, timestamp);
            }

            if (time_block != null && time_block.start_time != timestamp)
            {
                if (time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    this._scheduler.reschedule (session, timestamp);
                }
                else {
                    debug ("advance_to_time_block: advancing to a time-block that has already started");
                }
            }

            this.set_current_time_block_internal (session, time_block, timestamp);

            // TODO: ensure we schedule following blocks

            // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: is it the best place to do bump expiry-time?
        }

        public void advance_to_state (Pomodoro.State state,
                                      int64          timestamp = -1)
        {
            GLib.debug ("SessionManager.advance_to_state: %s", state.to_string ());

            Pomodoro.ensure_timestamp (ref timestamp);

            if (state == Pomodoro.State.UNDEFINED) {
                this.advance_to_time_block (null, timestamp);
                return;
            }

            // Extend current time-block
            if (this._current_time_block != null &&
                this._current_time_block.state == state &&
                !this._current_time_block.session.is_expired (timestamp))
            {
                this.advance_to_time_block (this._current_time_block, timestamp);
                return;
            }

            // Extend previous time-block, if uncompleted
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

            // Try to select upcoming state.
            var next_time_block = this.get_next_time_block ();
            var next_session = next_time_block != null ? next_time_block.session : null;

            if (next_session == null || next_session.is_expired (timestamp)) {
                next_session = this.initialize_session (timestamp);
                next_time_block = next_session.get_first_time_block ();
            }

            if (next_time_block != null && next_time_block.state != state) {
                var time_block = new Pomodoro.TimeBlock.with_start_time (timestamp, state=state);
                next_session.insert_before (time_block, next_time_block);
                next_time_block = time_block;
            }

            if (next_time_block == null) {
                next_time_block = new Pomodoro.TimeBlock.with_start_time (timestamp, state=state);
                next_session.append (next_time_block);
            }

            this.advance_to_time_block (next_time_block, timestamp);
        }

        public void advance (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var next_time_block = this.get_next_time_block ();
            var next_session = next_time_block != null ? next_time_block.session : null;

            if (next_session == null || next_session.is_expired (timestamp)) {
                next_session = this.initialize_session (timestamp);
                next_time_block = next_session.get_first_time_block ();
            }

            // if (next_time_block == null) {
            //     assert_not_reached ();
            //     // TODO: figure out next time-block state / duration
            //     // next_time_block = new Pomodoro.TimeBlock.with_start_time (state, timestamp);
            //     // next_session.append (next_time_block);
            // }

            this.advance_to_time_block (next_time_block, timestamp);
        }

        /**
         * Update resolving timer state according to current session.
         *
         * Start a session or reschedule existing in order to construct a final timer state.
         */
        private void resolve_timer_state (ref Pomodoro.TimerState state,
                                          int64                   timestamp)
        {
            debug ("###### resolve_timer_state: %lld", Pomodoro.Timestamp.peek ());

            // var timestamp = this._timer.get_last_state_changed_time ();
            //Pomodoro.ensure_timestamp (ref timestamp);

            if (this.timer_freeze_count > 0) {
                debug ("SessionManager.on_timer_resolve_state: A");
                return;
            }

            if (state.finished_time >= 0 && this.timer.get_last_action () == Pomodoro.TimerAction.SKIP)
            {
                this.advance (state.finished_time);

                return;
            }

            // Timer is paused or has finished. Nothing to resolve.
            // Advancing to a next time-block should be done after emitting `Timer.state_changed`.
            if (state.finished_time >= 0 || state.paused_time >= 0) {
                debug ("SessionManager.on_timer_resolve_state: B");
                return;
            }

            // Stopping (resetting) the timer.
            // Adjust state as if the timer has already stopped. Handling will be continued in `Timer.state_changed`.
            if (state.started_time < 0) {
                debug ("SessionManager.on_timer_resolve_state: C");
                state.user_data = null;
                this.advance_to_time_block (null, timestamp);
                return;
            }

            // Timer is started by a session manager.
            if (state.started_time >= 0 && state.user_data == this._current_time_block && this._current_time_block != null) {  //  && this.current_time_block_entered
                debug ("SessionManager.on_timer_resolve_state: D");
                return;
            }

            // Starting the timer. Handle expired session.
            if (this._current_session != null && this._current_session.is_expired (timestamp))
            {
                debug ("SessionManager.on_timer_resolve_state: session expired %lld", timestamp);
                // TODO: are timestamps correct here?
                // var next_session = this.initialize_session (state.started_time);
                // var next_time_block = current_session.get_first_time_block ();

                // this.advance_to_time_block (next_time_block, state.started_time);

                this.advance (state.started_time);

                this.initialize_timer_state (ref state, timestamp);  // TODO: can we use update_timer_state() ?
                return;
            }

            // Starting the timer.
            if (this._current_time_block == null) {  // || !this.current_time_block_entered
                debug ("SessionManager.on_timer_resolve_state: F");
                this.advance_to_state (Pomodoro.State.POMODORO, state.started_time);

                this.initialize_timer_state (ref state, timestamp);  // TODO: can we use update_timer_state() ?
                return;
            }

            assert (state.user_data == this._current_time_block);
            assert (this.current_time_block_entered == (this._current_time_block != null));
        }

        private void on_timer_resolve_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            this.resolving_timer_state++;
            this.resolve_timer_state (ref state, timestamp);
            this.resolving_timer_state--;
        }

        // public void handle_timer_finished ()
        // {
            // TODO: pause state and wait for user activity or popup notification to do so
            // TODO: we only want to pause or ask for confirmation only if timer finished on its own, not through
            //       skip action

        //     this.advance (this.timer.state.finished_time);
        // }

        /**
         * React to timer state changes.
         */
        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            debug ("SessionManager.on_timer_state_changed\n%s", current_state.to_representation ());

            // var timestamp = this.timer.get_last_state_changed_time ();

            if (this.timer_freeze_count > 0) {
                debug ("SessionManager.on_timer_state_changed: A");
                return;
            }

            // Stopped current time-block
            // if (current_state.user_data == null && this._current_time_block != null) {
            //     debug ("SessionManager.on_timer_state_changed: B");
                // TODO: use previous_state.finished_time as timestamp... or current_time_block.end_time
                // TODO: when you stop the timer does it have finished_time?
                // this.advance_to_time_block (null, timestamp);
            //     this.advance_to_time_block (null, this.timer.get_last_state_changed_time ());

            //     return;
            // }

            // Advance to next time-block
            // if (current_state.finished_time >= 0 && this._current_time_block != null) {
            //     debug ("SessionManager.on_timer_state_changed: C");
                // this.handle_timer_finished ();
            //     return;
            // }

            this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
        }

        private void on_timer_finished (Pomodoro.TimerState state)
        {
            // TODO: pause or ask whether we should advance
            this.advance (state.finished_time);
        }

        private void on_current_time_block_changed (Pomodoro.TimeBlock time_block)
        {
            debug ("on_current_time_block_changed");

            // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
        }

        private void on_settings_changed (string key)
        {
            switch (key)
            {
                case "pomodoro-duration":
                case "short-break-duration":
                case "long-break-duration":
                case "pomodoros-per-session":
                    this.update_session_template ();
                    break;
            }
        }

        // TODO: move it to timer-state-changed handler
        //       bump session from timer.state.user_data
        private void bump_expiry_time (int64 timeout)
        {
            if (this._current_session != null)
            {
                var expiry_time = Pomodoro.Timestamp.UNDEFINED;
                var current_or_previous_time_block = this._current_time_block != null
                    ? this._current_time_block
                    : this.previous_time_block;

                if (this.timer.is_finished ()) {
                    expiry_time = this.timer.state.finished_time + timeout;
                }
                else if (this.timer.is_paused ()) {
                    expiry_time = this.timer.state.paused_time + timeout;
                }
                else if (this.timer.is_started ()) {
                    expiry_time = this.timer.state.started_time + this.timer.state.duration + timeout;
                }
                else if (current_or_previous_time_block != null) {
                    expiry_time = current_or_previous_time_block.end_time + timeout;
                }

                this._current_session.set_expiry_time (expiry_time);
            }
        }

        /**
         * Session is entered as soon as current-session property is set.
         */
        [Signal (run = "first")]
        public signal void enter_session (Pomodoro.Session session)
        {
            assert (session == this._current_session);
            debug ("SessionManager.enter_session");

            this.current_session_entered = true;

            // TODO
            // this.current_session_expired_id = session.expired.connect (this.on_current_session_expired);
        }

        [Signal (run = "first")]
        public signal void leave_session (Pomodoro.Session session)
        {
            assert (session == this._current_session);
            debug ("SessionManager.leave_session");

            this.current_session_entered = false;

            // TODO
            // if (this.current_session_expired_id != 0) {
            //     session.disconnect (this.current_session_expired_id);
            //     this.current_session_expired_id = 0;
            // }
        }

        /**
         * Time block is entered as soon as current-time-block property is set.
         * You should check timer whether time block has really started.
         */
        [Signal (run = "first")]
        public signal void enter_time_block (Pomodoro.TimeBlock time_block)  // TODO: pass Event instance if available
        {
            assert (time_block == this._current_time_block);
            assert (time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);  // TODO: may not be true, if reusing the time-block

            // assert (this.timer.user_data == time_block);
            debug ("SessionManager.enter_time_block start_time=%lld", time_block.start_time);

            var session = time_block.session;
            var time_block_status = time_block.get_status ();
            // var timestamp = this.timer.state.started_time > 0 ? this.timer.state.started_time : time_block.start_time;  // TODO: is this correct?

            // if (time_block_status > Pomodoro.TimeBlockStatus.IN_PROGRESS) {
            //     GLib.warning ("Entering a time-block that has been started before.");
            // }

            if (this.current_time_block_changed_id != 0) {
                GLib.warning ("TimeBlock.changed signal handler has not been disconnected properly");
            }

            this.current_time_block_entered = true;
            this.current_time_block_changed_id = time_block.changed.connect (this.on_current_time_block_changed);

            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
        }

        [Signal (run = "first")]
        public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        {
            assert (time_block == this._current_time_block);
            assert (time_block.get_status () == Pomodoro.TimeBlockStatus.COMPLETED ||
                    time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);

            debug ("SessionManager.leave_time_block");

            // assert (this.timer.user_data == time_block);

            // if (time_block != this._current_time_block) {
            //     GLib.debug ("Ignoring `leave-time-block` signal. It expects that the time-block is still regarded as current during emission.");
            //     return;
            // }

            this.current_time_block_entered = false;

            if (this.current_time_block_changed_id != 0) {  // TODO: likely this shouldn't be
                time_block.disconnect (this.current_time_block_changed_id);
                this.current_time_block_changed_id = 0;
            }


            // var session      = time_block.session;
            // var timestamp    = this.timer.state.finished_time > 0 ? this.timer.state.finished_time : time_block.end_time; // TODO: is it correct?
            // var has_finished = (this.timer.user_data == time_block) && this.timer.is_finished ();  // TODO: to test
            // var completed    = time_block.is_completed (has_finished, this.strictness, timestamp);

            // session.mark_time_block_ended (time_block, completed, timestamp);  // TODO: should be in resolve state

            // session.reschedule (this._session_template, this.strictness, timestamp);
        }

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

            if (this.timer_finished_id != 0) {
                this.timer.disconnect (this.timer_finished_id);
                this.timer_finished_id = 0;
            }

            base.dispose ();
        }
    }
}



        // public signal void state_changed (Pomodoro.State current_state,
        //                                   Pomodoro.State previous_state)
        // {
        //     debug ("SessionManager.state_changed");
        // }

        /*
        private void mark_current_time_block_ended (bool  has_timer_finished,
                                                    int64 timestamp)  // TODO: pass whether timer has finished natually, or timeblock was changed manually
        {
            var time_block = this._current_time_block;

            if (time_block == null) {
                return;
            }

            if (time_block.status == Pomodoro.TimeBlockStatus.COMPLETED ||
                time_block.status == Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                return;
            }

            debug ("mark_current_time_block_ended(%lld)", timestamp);

            time_block.end_time = timestamp;

            // TODO determine whether timeblock completed
            if (has_timer_finished &&
                time_block.status == Pomodoro.TimeBlockStatus.IN_PROGRESS &&
                time_block.duration > 0  // MIN_TIME_BLOCK_DURATION
            ) {
                time_block.status = Pomodoro.TimeBlockStatus.COMPLETED;
            }
            else {
                time_block.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;
            }

            this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: should be called in on_changed handler for the current_time_block
        }

        private void mark_current_session_ended (bool  has_timer_finished,
                                                 int64 timestamp)
        {
            if (this._current_session == null) {
                return;
            }

            if (this._current_time_block != null) {
                this._current_session.remove_after (this._current_time_block);

                this.mark_current_time_block_ended (has_timer_finished, timestamp);
            }
        }
        */


        /*
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
        */

        // private Pomodoro.SessionTemplate      _session_template;
        // private Pomodoro.Strictness           _strictness = Pomodoro.Strictness.STRICT;


        // [CCode(notify = false)]
        // public Pomodoro.Strictness strictness {
        //     get {
        //         return this._strictness;
        //     }
        //     set {
        //         if (this._strictness == value) {
        //             return;
        //         }

        //         this._strictness = value;

        //         this.notify_property ("strictness");
        //     }
        // }

        // /**
        //  * Session template
        //  */
        // [CCode(notify = false)]
        // public Pomodoro.SessionTemplate session_template {
        //     get {
        //         return this._session_template;
        //     }
        // }
