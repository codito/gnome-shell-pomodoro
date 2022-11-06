namespace Pomodoro
{
    public enum Strictness
    {
        STRICT,
        LENIENT;

        /**
         * Return a fallback stricness if none is specified.
         */
        public static Pomodoro.Strictness get_default ()
        {
            // TODO: return from settings, not the SessionManager

            var session_manager = Pomodoro.SessionManager.get_default ();
            if (session_manager != null) {
                return session_manager.strictness;
            }

            return Pomodoro.Strictness.STRICT;
        }
    }

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
        public Pomodoro.Strictness strictness {
            get {
                return this._strictness;
            }
            set {
                if (this._strictness == value) {
                    return;
                }

                this._strictness = value;

                this.notify_property ("strictness");
            }
        }

        /**
         * Session template
         */
        [CCode(notify = false)]
        public Pomodoro.SessionTemplate session_template {
            get {
                return this._session_template;
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
        private Pomodoro.SessionTemplate         _session_template;
        private Pomodoro.Session?                _current_session = null;
        private Pomodoro.TimeBlock?              _current_time_block = null;
        private bool                             current_time_block_entered = false;
        private ulong                            current_time_block_changed_id = 0;
        private bool                             current_session_entered = false;
        private Pomodoro.Session?                previous_session = null;
        private Pomodoro.TimeBlock?              previous_time_block = null;
        private Pomodoro.Strictness              _strictness = Pomodoro.Strictness.STRICT;
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
            // TODO: monitor settings and update it
            this._session_template = Pomodoro.SessionTemplate ();
        }

        private void update_timer_state (int64 timestamp = -1)
        {
            var time_block = this._current_time_block;

            if (this.resolving_timer_state != 0) {
                return;
            }

            this.freeze_timer ();

            if (time_block != null) {
                Pomodoro.ensure_timestamp (ref timestamp);
                this._timer.state = Pomodoro.TimerState () {  // FIXME when resolving the state, we want to propagate this through call stack
                    duration      = time_block.end_time - time_block.start_time,
                    offset        = time_block.calculate_elapsed (timestamp),
                    started_time  = time_block.start_time,
                    paused_time   = Pomodoro.Timestamp.UNDEFINED,
                    finished_time = Pomodoro.Timestamp.UNDEFINED,
                    user_data     = time_block
                };
            }
            else {
                this._timer.reset ();
            }

            this.thaw_timer ();
        }

        private void set_current_time_block_internal (Pomodoro.Session?        session,
                                                      Pomodoro.TimeBlock?      time_block)
        {
            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;
            var timestamp           = this._timer.get_last_state_changed_time ();

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
                    this.current_time_block_entered = false;  // TODO: place it inside handler

                    // var session      = time_block.session;
                    // var timestamp    = this.timer.state.finished_time > 0 ? this.timer.state.finished_time : time_block.end_time; // TODO: is it correct?
                    var has_finished = (this.timer.user_data == time_block) && this.timer.is_finished ();  // TODO: to test
                    var completed    = time_block.is_completed (has_finished, this.strictness, timestamp);

                    session.mark_time_block_ended (time_block, completed, timestamp);  // TODO: should be in resolve state
                    session.reschedule (this._session_template, this.strictness, timestamp);

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

            // Enter time-block. It will start or stop the timer depending whether time-block is null.
            if (time_block != previous_time_block)
            {
                this.previous_session    = previous_session;
                this.previous_time_block = previous_time_block;
                this._current_time_block = time_block;

                this.notify_property ("current-time-block");

                this.update_timer_state ();

                // // TODO: these should be emitted based on timer state
                // this.current_time_block_entered = true;  // TODO: place it inside handler
                // this.enter_time_block (time_block);
                // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // changing timer state should be enough
            }
        }

        private unowned Pomodoro.TimeBlock? get_next_time_block ()
        {
            if (this._current_session == null) {
                debug ("get_next_time_block(): null");
                return null;
            }

            if (this._current_time_block == null) {
                debug ("get_next_time_block(): first");
                return this._current_session.get_first_time_block ();
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

        public unowned Pomodoro.TimeBlock? get_current_or_previous_time_block ()
        {
            return this._current_time_block != null
                ? this._current_time_block
                : this.previous_time_block;
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
            debug ("SessionManager.initialize_session");

            // TODO: in future we may want to align time-blocks according to agenda/scheduled events

            var session = new Pomodoro.Session.from_template (Pomodoro.SessionTemplate (), timestamp);

            session.@foreach (
                time_block => {
                    time_block.set_data<int64> ("intended-duration", time_block.duration);
                    time_block.set_data<bool> ("completed", false);
                    // time_block.set_data<bool> ("skipped", false);
                }
            );

            return session;
        }

        private void initialize_timer_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            debug ("SessionManager.initialize_timer_state");

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

        /**
         * Start given time-block
         *
         * While `set_current_time_block_internal` only marks which timeblock and session is current,
         * advance* methods modify session and time-blocks:
         *   - time-block is shifted to `timestamp`
         *   - session is adjusted accordingly
         */
        private void advance_to_time_block (Pomodoro.TimeBlock? time_block,
                                            int64               timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var session = time_block != null ? time_block.session : this._current_session;

            if (time_block != null) {
                debug("advance_to_time_block: %d", time_block.session.index (time_block));
            }

            if (time_block == this._current_time_block && !time_block.has_ended (timestamp)) {
                debug("advance_to_time_block: extend_current_time_block");
                this.extend_current_time_block (timestamp);
                // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: is it the best place to do bump expiry-time?
                return;
            }

            if (this._current_time_block != null)
            {
                assert (this.timer.state.user_data == this._current_time_block);  // TODO: remove

                var has_finished = (
                    this.timer.state.user_data == this._current_time_block &&
                    this.timer.state.finished_time > 0
                );
                var has_completed = this._current_time_block.is_completed (
                    has_finished,
                    this.strictness,
                    has_finished ? this.timer.state.finished_time : timestamp
                );

                this._current_session.mark_time_block_ended (this._current_time_block, has_completed, timestamp);
            }

            if (this._current_session != null && this._current_session != session) {
                this._current_session.finish (timestamp);  // TODO: pass strictness?
            }

            if (time_block != null) {
                time_block.session.reschedule (this._session_template, this.strictness);
            }

            this.set_current_time_block_internal (session, time_block);
            // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);  // TODO: is it the best place to do bump expiry-time?
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
            var next_time_block = this.get_next_time_block ();
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

            // Insert a break at the beginning of session if requested
            if (next_time_block != null && next_time_block.state != state) {
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

        private int resolving_timer_state = 0;

        private void resolve_timer_state (ref Pomodoro.TimerState state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            Pomodoro.ensure_timestamp (ref timestamp);

            if (this.timer_freeze_count > 0) {
                debug ("SessionManager.on_timer_resolve_state: A");
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

                this.initialize_timer_state (ref state, timestamp);
                return;
            }

            // Starting the timer.
            if (this._current_time_block == null) {  // || !this.current_time_block_entered
                debug ("SessionManager.on_timer_resolve_state: F");
                this.advance_to_state (Pomodoro.State.POMODORO, state.started_time);

                this.initialize_timer_state (ref state, timestamp);
                return;
            }

            assert (state.user_data == this._current_time_block);
            assert (this.current_time_block_entered == (this._current_time_block != null));
        }

        private void on_timer_resolve_state (ref Pomodoro.TimerState state)
        {
            this.resolving_timer_state++;
            this.resolve_timer_state (ref state);
            this.resolving_timer_state--;
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            debug ("SessionManager.on_timer_state_changed");

            // var timestamp = this.timer.get_last_state_changed_time ();

            if (this.timer_freeze_count > 0) {
                debug ("SessionManager.on_timer_state_changed: A");
                return;
            }

            // Stopped current time-block
            if (current_state.user_data == null && this._current_time_block != null) {
                debug ("SessionManager.on_timer_state_changed: B");
                // TODO: use previous_state.finished_time as timestamp... or current_time_block.end_time
                // TODO: when you stop the timer does it have finished_time?
                // this.advance_to_time_block (null, timestamp);
                this.advance_to_time_block (null, this.timer.get_last_state_changed_time ());

                return;
            }

            // Advance to next time-block
            if (current_state.finished_time >= 0 && this._current_time_block != null) {
                debug ("SessionManager.on_timer_state_changed: C");
                // TODO: pause state and wait for user activity

                this.advance (current_state.finished_time);
                return;
            }

            this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
        }

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

        private void on_timer_finished (Pomodoro.TimerState state)
        {
            // var time_block = state.user_data as Pomodoro.TimeBlock;

            // if (time_block != null) {
            //     time_block.session.mark_time_block_ended (time_block, state);
            // }
        }

        private void on_current_time_block_changed (Pomodoro.TimeBlock time_block)
        {
            debug ("on_current_time_block_changed");

            // this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
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
        public signal void enter_session (Pomodoro.Session session)
        {
            debug ("SessionManager.enter_session");

            // TODO
            // this.current_session_expired_id = session.expired.connect (this.on_current_session_expired);
        }

        public signal void leave_session (Pomodoro.Session session)
        {
            debug ("SessionManager.leave_session");

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
        public signal void enter_time_block (Pomodoro.TimeBlock time_block)  // TODO: pass Event instance if available
        {
            var session = time_block.session;
            var timestamp = this.timer.state.started_time > 0 ? this.timer.state.started_time : time_block.start_time;  // TODO: is this correct

            assert (this.timer.user_data == time_block);

            debug ("SessionManager.enter_time_block");

            // if (time_block.skipped) {
            //     GLib.warning ("Entering a time-block that has been skipped before");
            // }

            if (this.current_time_block_changed_id != 0) {
                GLib.warning ("TimeBlock.changed signal handler has not been disconnected properly");
            }

            this.current_time_block_changed_id = time_block.changed.connect (this.on_current_time_block_changed);

            session.mark_time_block_started (time_block, timestamp);
        }

        public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        {
            debug ("SessionManager.leave_time_block");
            // assert (this.timer.user_data == time_block);

            if (time_block != this._current_time_block) {
                return;
            }

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

        // public signal void state_changed (Pomodoro.State current_state,
        //                                   Pomodoro.State previous_state)
        // {
        //     debug ("SessionManager.state_changed");
        // }

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
