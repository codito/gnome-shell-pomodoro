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

                if (this._scheduler != null && this.scheduler_notify_session_template_id != 0) {
                    this._scheduler.disconnect (this.scheduler_notify_session_template_id);
                }

                if (this._scheduler != null && this.scheduler_rescheduled_session_id != 0) {
                    this._scheduler.disconnect (this.scheduler_rescheduled_session_id);
                }

                this._scheduler = value;

                if (this._scheduler != null)
                {
                    this.scheduler_notify_session_template_id = this._scheduler.notify["session-template"].connect (this.on_scheduler_notify_session_template);
                    this.scheduler_rescheduled_session_id = this._scheduler.rescheduled_session.connect (this._on_rescheduled_session);

                    if (this._current_session != null) {
                        this._scheduler.reschedule (this._current_session);
                    }
                }

                this.notify_property ("scheduler");
            }
        }

        /**
         * A current session.
         *
         * Setter replaces current session with another one without adjusting either of them.
         * To correct the timing use `advance_*` methods. After selecting session manually, the current time-block
         * is null and the timer is stopped.
         */
        [CCode(notify = false)]
        public unowned Pomodoro.Session current_session {
            get {
                return this._current_session;
            }
            set {
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
                this.set_current_time_block_internal (
                    value != null ? value.session : this._current_session,
                    value);
            }
        }

        private Pomodoro.Timer                   _timer;
        private Pomodoro.Scheduler               _scheduler;
        private Pomodoro.Session?                _current_session = null;
        private Pomodoro.TimeBlock?              _current_time_block = null;
        private Pomodoro.Gap?                    _current_gap = null;
        private bool                             current_time_block_entered = false;
        private ulong                            current_time_block_changed_id = 0;
        private bool                             current_session_entered = false;
        private ulong                            current_session_notify_expiry_time_id = 0;
        private Pomodoro.Session?                previous_session = null;
        private Pomodoro.TimeBlock?              previous_time_block = null;
        private GLib.Settings                    settings;
        private int                              resolving_timer_state = 0;
        private int                              timer_freeze_count = 0;
        private ulong                            timer_resolve_state_id = 0;
        private ulong                            timer_state_changed_id = 0;
        private ulong                            timer_suspended_id = 0;
        private ulong                            timer_finished_id = 0;
        private uint                             expiry_timeout_id = 0;
        private ulong                            scheduler_notify_session_template_id = 0;
        private ulong                            scheduler_rescheduled_session_id = 0;
        private uint                             reschedule_idle_id = 0;


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
            this.scheduler = new Pomodoro.SimpleScheduler ();

            this.settings.changed.connect (this.on_settings_changed);

            this.update_session_template ();
        }

        private void update_session_template ()
        {
            var pomodoro_duration = this.settings.get_uint ("pomodoro-duration");
            var short_break_duration = this.settings.get_uint ("short-break-duration");
            var long_break_duration = this.settings.get_uint ("long-break-duration");
            var cycles = this.settings.get_uint ("pomodoros-per-session");

            var session_template = Pomodoro.SessionTemplate () {
                pomodoro_duration = Pomodoro.Timestamp.from_seconds_uint (pomodoro_duration),
                short_break_duration = Pomodoro.Timestamp.from_seconds_uint (short_break_duration),
                long_break_duration = Pomodoro.Timestamp.from_seconds_uint (long_break_duration),
                cycles = cycles
            };

            this._scheduler.session_template = session_template;
        }

        private void update_timer_state (int64 timestamp)
        {
            var time_block = this._current_time_block;

            if (this.resolving_timer_state != 0) {
                return;
            }

            this.freeze_timer ();

            if (time_block != null) {
                this._timer.state = Pomodoro.TimerState () {
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

        private void _on_rescheduled_session ()
        {
            if (this.reschedule_idle_id != 0) {
                GLib.Source.remove (this.reschedule_idle_id);
                this.reschedule_idle_id = 0;
            }
        }

        /**
         * Try reschedule current session.
         */
        private void reschedule ()
        {
            if (this.reschedule_idle_id != 0) {
                GLib.Source.remove (this.reschedule_idle_id);
                this.reschedule_idle_id = 0;
            }

            if (this._scheduler != null && this._current_session != null) {
                this._scheduler.reschedule (this._current_session, this.get_current_time ());
            }
        }

        /**
         * Try reschedule current session, if it was queued.
         */
        private void reschedule_if_queued ()
        {
            if (this.reschedule_idle_id != 0) {
                this.reschedule ();
            }
        }

        private void queue_reschedule ()
        {
            if (this._current_session == null) {
                return;
            }

            if (this.reschedule_idle_id != 0) {
                return;
            }

            this.reschedule_idle_id = GLib.Idle.add (
                () => {
                    this.reschedule_idle_id = 0;
                    this.reschedule ();

                    return GLib.Source.REMOVE;
                },
                GLib.Priority.HIGH_IDLE
            );
        }

        private void set_current_time_block_internal (Pomodoro.Session?   session,
                                                      Pomodoro.TimeBlock? time_block,
                                                      int64               timestamp = -1)
        {
            if (session == this._current_session && time_block == this._current_time_block) {
                return;
            }

            if (time_block != null) {
                assert (time_block.session != null);
                assert (time_block.session == session);
            }

            if (Pomodoro.Timestamp.is_undefined (timestamp)) {
                timestamp = this._timer.get_last_state_changed_time ();  // TODO: is this correct?
            }

            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;

            // Leave previous time-block.
            if (previous_time_block != null)
            {
                if (previous_time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    this.mark_time_block_end (previous_time_block, timestamp);
                }

                if (this.current_time_block_entered) {
                    this.leave_time_block (previous_time_block);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    // A different time-block was set during `leave_time_block()` emission.
                    return;
                }
            }

            // Leave previous session.
            if (previous_session != null && session != previous_session)
            {
                this.mark_session_end (previous_session, timestamp);

                if (this.current_session_entered) {
                    this.leave_session (previous_session);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    // A different time-block was set during `leave_session()` emission.
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
                this._current_gap        = null;
                this._current_time_block = time_block;
                this.notify_property ("current-time-block");

                if (time_block != null) {
                    this.enter_time_block (time_block);
                }

                this.update_timer_state (timestamp);
            }
        }

        private unowned Pomodoro.TimeBlock? get_next_time_block ()
        {
            if (this._current_session == null) {
                return null;
            }

            if (this._current_time_block == null)
            {
                if (this.previous_time_block != null &&
                    this.previous_session == this._current_session)
                {
                    return this._current_session.get_next_time_block (this.previous_time_block);
                }
                else {
                    return this._current_session.get_first_time_block ();
                }
            }

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
        public void save (int64 timestamp = -1)
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

        private int64 get_current_time ()
        {
            return this.resolving_timer_state > 0
                ? this._timer.get_last_state_changed_time ()
                : this._timer.get_current_time ();
        }

        private Pomodoro.Session initialize_session (int64 timestamp)
        {
            var session = new Pomodoro.Session ();

            this._scheduler.reschedule (session, timestamp);

            return session;
        }

        private void initialize_timer_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            var current_time_block = this._current_time_block;

            // Adjust timer state according to current-time-block.
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

        /**
         * Extend current time-block, as if it was started from scratch.
         */
        private void extend_current_time_block (int64 timestamp)
                                                requires (this._current_time_block != null)
                                                requires (this._current_time_block == this._timer.user_data)
        {
            var current_time_block_meta = this._current_time_block.get_meta ();
            var started_time = this._timer.started_time;

            if (Pomodoro.Timestamp.is_undefined (started_time)) {
                started_time = timestamp;
            }

            this._timer.state = Pomodoro.TimerState () {
                duration      = current_time_block_meta.intended_duration,
                offset        = Pomodoro.Timestamp.subtract (timestamp, started_time),
                started_time  = started_time,
                paused_time   = Pomodoro.Timestamp.UNDEFINED,
                finished_time = Pomodoro.Timestamp.UNDEFINED,
                user_data     = this._current_time_block
            };
        }

        /**
         * Adjust time-blocks `end-time` and its status.
         */
        private void mark_time_block_end (Pomodoro.TimeBlock time_block,
                                          int64              timestamp)
                                          requires (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS)
                                          ensures (time_block.end_time <= timestamp)
        {
            var has_finished = (
                this.timer.user_data == time_block &&
                this.timer.is_finished ()
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
            time_block.foreach_gap ((gap) => {
                gap.end_time = Pomodoro.Timestamp.is_undefined (gap.end_time)
                    ? timestamp
                    : int64.min (gap.end_time, timestamp);
            });
        }

        /**
         * Discard time-blocks that were not marked as ended.
         * Time block that was in-progress should be marked
         */
        private void mark_session_end (Pomodoro.Session session,
                                       int64            timestamp)
                                       ensures (session.end_time <= timestamp)
        {
            session.freeze_changed ();
            session.remove_scheduled ();

            var last_time_block = session.get_last_time_block ();

            if (last_time_block != null) {
                // Time-block should be marked as ended earlier, and leave-time-block should be already emitted.
                assert (last_time_block.get_status () != Pomodoro.TimeBlockStatus.IN_PROGRESS);
            }

            session.thaw_changed ();
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

            if (time_block == this._current_time_block) {
                return;
            }

            // We need to unmark in-progress status for the current time-block before rescheduling.
            if (this._current_time_block != null) {
                this.mark_time_block_end (this._current_time_block, timestamp);
            }

            // Run rescheduling to make sure the next time-block is up to date.
            // Skip rescheduling if time-block if session appears to be just populated.
            if (time_block != null && time_block.start_time != timestamp)
            {
                if (time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    this._scheduler.reschedule (session, timestamp);
                }
                else {
                    GLib.debug ("SessionManager.advance_to_time_block: Advancing to a time-block that has already started");
                }
            }

            this.set_current_time_block_internal (session, time_block, timestamp);
        }

        public void advance_to_state (Pomodoro.State state,
                                      int64          timestamp = -1)
        {
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
                this.extend_current_time_block (timestamp);
                return;
            }

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

            this.advance_to_time_block (next_time_block, timestamp);
        }

        private void bump_expiry_time (int64 timeout)
        {
            if (this.expiry_timeout_id != 0)
            {
                GLib.Source.remove (this.expiry_timeout_id);
                this.expiry_timeout_id = 0;
            }

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

                this._current_session.expiry_time = expiry_time;
            }
        }

        private void update_current_time_block (Pomodoro.TimerState current_state,
                                                Pomodoro.TimerState previous_state,
                                                int64               timestamp)
                                                requires (current_state.user_data == this._current_time_block)
                                                requires (this._current_time_block != null)
        {
            var current_time_block = this._current_time_block;

            // Handle duration change.
            if (Pomodoro.Timestamp.is_undefined (current_state.paused_time)) {
                var end_time = Pomodoro.Timestamp.is_defined (current_state.started_time)
                    ? current_state.started_time + current_state.offset + current_state.duration
                    : current_time_block.start_time + current_state.offset + current_state.duration;

                current_time_block.end_time = end_time;
            }

            if (current_state.user_data == previous_state.user_data &&
                current_state.paused_time == previous_state.paused_time &&
                current_state.offset != previous_state.offset)
            {
                // Handle rewind.
                var gap_start_time = Pomodoro.Timestamp.is_defined (current_state.paused_time)
                    ? current_state.paused_time : timestamp;
                var gap_end_time = timestamp;

                gap_start_time = Pomodoro.Timestamp.subtract_interval (
                                         gap_start_time,
                                         current_state.offset - previous_state.offset);

                if (this._current_gap == null) {
                    this._current_gap = new Pomodoro.Gap ();
                    this._current_gap.set_time_range (gap_start_time, gap_end_time);
                    this._current_time_block.add_gap (this._current_gap);
                }
                else {
                    this._current_gap.start_time = gap_start_time;
                }
            }
            else if (Pomodoro.Timestamp.is_defined (current_state.paused_time))
            {
                // Mark pause start.
                this._current_gap = new Pomodoro.Gap.with_start_time (current_state.paused_time);
                this._current_time_block.add_gap (this._current_gap);
            }
            else {
                // Mark pause end.
                if (this._current_gap != null) {
                    this._current_gap.end_time = timestamp;
                    this._current_gap = null;
                }
            }
        }

        /**
         * Update resolving timer state according to current session.
         *
         * Start a session or reschedule existing in order to construct a final timer state.
         */
        private void resolve_timer_state (ref Pomodoro.TimerState state,
                                          int64                   timestamp)
                                          ensures (state.user_data == this._current_time_block)
                                          ensures (this.current_time_block_entered == (this._current_time_block != null))
        {
            if (this.timer_freeze_count > 0) {
                return;
            }

            // Timer is paused or has finished. Nothing to resolve.
            // Advancing to a next time-block should be done after emitting `Timer.state_changed`.
            if (Pomodoro.Timestamp.is_defined (state.finished_time) || Pomodoro.Timestamp.is_defined (state.paused_time)) {
                return;
            }

            // Stopping (resetting) the timer.
            // Adjust state as if the timer has already stopped. Handling will be continued in `Timer.state_changed`.
            if (Pomodoro.Timestamp.is_undefined (state.started_time)) {
                this.advance_to_time_block (null, timestamp);
                state.user_data = null;  // TODO: can we use initialize_timer_state() / update_timer_state() ?
                return;
            }

            // Timer is started by a session manager.
            if (state.user_data == this._current_time_block && this._current_time_block != null) {
                return;
            }

            // Starting the timer when current session expired.
            if (this._current_session != null && this._current_session.is_expired (timestamp))
            {
                this.advance (state.started_time);
                this.initialize_timer_state (ref state, timestamp);  // TODO: can we use update_timer_state() ?
                return;
            }

            // Starting the timer.
            if (this._current_time_block == null)
            {
                this.advance_to_state (Pomodoro.State.POMODORO, state.started_time);
                this.initialize_timer_state (ref state, timestamp);  // TODO: can we use update_timer_state() ?
                return;
            }
        }

        private void on_timer_resolve_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            this.resolving_timer_state++;

            this.resolve_timer_state (ref state, timestamp);

            if (this._current_time_block != null) {
                this.update_current_time_block (state, this._timer.state, timestamp);
            }

            this.resolving_timer_state--;
        }

        /**
         * React to timer state changes.
         */
        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            // HACK: Use `resolving_timer_state` to preserve original timestamp
            //       in `on_current_session_notify_expiry_time()`.
            this.resolving_timer_state++;
            this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
            this.reschedule_if_queued ();
            this.resolving_timer_state--;
        }

        private void on_timer_finished (Pomodoro.TimerState state)
        {
            // TODO: pause or ask whether we should advance

            this.advance (state.finished_time);
        }

        private void on_current_time_block_changed (Pomodoro.TimeBlock time_block)
        {
            if (this.resolving_timer_state == 0) {
                this._scheduler.reschedule (this._current_session, this.get_current_time ());
            }
            else {
                this.queue_reschedule ();
            }
        }

        private void on_scheduler_notify_session_template ()
        {
            this.queue_reschedule ();
        }

        /**
         * A wrapper for `Timeout.add_seconds`.
         * We don't want expiry callback to increment the reference counter, hence the static method and the use of pointer.
         */
        private static uint setup_expiry_timeout (uint  seconds,
                                                  void* session_manager_ptr)
        {
            weak Pomodoro.SessionManager session_manager = (Pomodoro.SessionManager) session_manager_ptr;

            return GLib.Timeout.add_seconds (seconds,
                () => {
                    session_manager.expiry_timeout_id = 0;
                    session_manager.current_session = null;

                    return GLib.Source.REMOVE;
                }
            );
        }

        private void on_current_session_notify_expiry_time ()
        {
            var current_time = this.get_current_time ();

            if (this.expiry_timeout_id != 0) {
                GLib.Source.remove (this.expiry_timeout_id);
                this.expiry_timeout_id = 0;
            }

            if (this._current_session.expiry_time > current_time)
            {
                var timeout_seconds = Pomodoro.Timestamp.to_seconds_uint (
                    Pomodoro.Timestamp.round_seconds (this._current_session.expiry_time - current_time));

                this.expiry_timeout_id = Pomodoro.SessionManager.setup_expiry_timeout (timeout_seconds, this);
            }
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

                // TODO: choose scheduler
            }
        }

        /**
         * Session is entered as soon as current-session property is set.
         */
        [Signal (run = "first")]
        public signal void enter_session (Pomodoro.Session session)
        {
            assert (session == this._current_session);

            this.current_session_entered = true;
            this.current_session_notify_expiry_time_id =
                this._current_session.notify["expiry-time"].connect (this.on_current_session_notify_expiry_time);
        }

        [Signal (run = "first")]
        public signal void leave_session (Pomodoro.Session session)
        {
            assert (session == this._current_session);

            session.disconnect (this.current_session_notify_expiry_time_id);

            this.current_session_entered = false;
            this.current_session_notify_expiry_time_id = 0;
        }

        /**
         * Time block is entered as soon as current-time-block property is set.
         * You should check timer whether time block has really started.
         */
        [Signal (run = "first")]
        public signal void enter_time_block (Pomodoro.TimeBlock time_block)
        {
            assert (time_block == this._current_time_block);
            assert (time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);

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

            this.current_time_block_entered = false;

            if (this.current_time_block_changed_id != 0) {
                time_block.disconnect (this.current_time_block_changed_id);
                this.current_time_block_changed_id = 0;
            }
        }

        public override void dispose ()
        {
            if (Pomodoro.SessionManager.instance == this) {
                Pomodoro.SessionManager.instance = null;
            }

            if (this._timer != null && this.timer_resolve_state_id != 0) {
                this._timer.disconnect (this.timer_resolve_state_id);
                this.timer_resolve_state_id = 0;
            }

            if (this._timer != null && this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            if (this._timer != null && this.timer_suspended_id != 0) {
                this._timer.disconnect (this.timer_suspended_id);
                this.timer_suspended_id = 0;
            }

            if (this._timer != null && this.timer_finished_id != 0) {
                this._timer.disconnect (this.timer_finished_id);
                this.timer_finished_id = 0;
            }

            if (this._scheduler != null && this.scheduler_notify_session_template_id != 0) {
                this._scheduler.disconnect (this.scheduler_notify_session_template_id);
                this.scheduler_notify_session_template_id = 0;
            }

            if (this.reschedule_idle_id != 0) {
                GLib.Source.remove (this.reschedule_idle_id);
                this.reschedule_idle_id = 0;
            }

            if (this.expiry_timeout_id != 0) {
                GLib.Source.remove (this.expiry_timeout_id);
                this.expiry_timeout_id = 0;
            }

            this.settings = null;
            this._current_gap = null;
            this._current_time_block = null;
            this._current_session = null;
            this._timer = null;
            this._scheduler = null;

            base.dispose ();
        }
    }
}
