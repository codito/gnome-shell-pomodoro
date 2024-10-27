using GLib;


namespace Pomodoro
{
    private enum AdvancementMode
    {
        CONTINUOUS,
        MANUAL,
        WAIT_FOR_ACTIVITY
    }


    /**
     * `SessionManager` sets up the timer, advances time-blocks and sessions.
     */
    public class SessionManager : GLib.Object
    {
        /**
         * Idle time after which session should no longer be continued, and new session should be created.
         */
        public const int64 SESSION_EXPIRY_TIMEOUT = Pomodoro.Interval.HOUR;

        /**
         * Time limit when waiting for activity or confirmation.
         */
        private const int64 OVERDUE_TIMEOUT = Pomodoro.Interval.HOUR;

        /**
         * Idle time to require confirmation to advance to a break.
         */
        private const int64 CONTINOUS_ADVANCEMENT_IDLE_TIME_LIMIT = Pomodoro.Interval.MINUTE;

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
                this.timer_suspending_id = this._timer.suspended.connect (this.on_timer_suspending);
                this.timer_suspended_id = this._timer.suspended.connect (this.on_timer_suspended);
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

                this._scheduler = value;

                if (this._scheduler != null)
                {
                    this.scheduler_notify_session_template_id = this._scheduler.notify["session-template"].connect (
                            this.on_scheduler_notify_session_template);

                    if (this._current_session != null) {
                        this._scheduler.reschedule_session (this._current_session);
                    }
                }

                this.update_has_uniform_breaks ();

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
                this.set_current_time_block_full (value, null);
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
                this.set_current_time_block_full (value != null ? value.session : this._current_session, value);
            }
        }

        /**
         * Convenience property to track current state.
         */
        [CCode(notify = false)]
        public Pomodoro.State current_state {
            get {
                return this._current_state;
            }
            set {
                this.advance_to_state (value);
            }
        }

        /**
         * Convenience property to track whether there are several cycles per session.
         *
         * It equivalent to whether a session has short breaks.
         */
        [CCode(notify = false)]
        public bool has_uniform_breaks {
            get {
                return this._has_uniform_breaks;
            }
        }

        private Pomodoro.Timer                   _timer;
        private Pomodoro.Scheduler               _scheduler;
        private Pomodoro.Session?                _current_session = null;
        private Pomodoro.TimeBlock?              _current_time_block = null;
        private Pomodoro.State                   _current_state = Pomodoro.State.STOPPED;
        private Pomodoro.Session?                next_session = null;
        private Pomodoro.TimeBlock?              next_time_block = null;
        private Pomodoro.Gap?                    _current_gap = null;
        private Pomodoro.IdleMonitor?            idle_monitor = null;
        private Pomodoro.TimeZoneMonitor?        timezone_monitor = null;
        private Pomodoro.TimezoneHistory?        timezone_history = null;
        private Pomodoro.ScreenSaver?            screensaver = null;
        private Pomodoro.LockScreen?             lockscreen = null;
        private bool                             auto_paused = false;
        private bool                             _has_uniform_breaks = false;
        private bool                             current_time_block_entered = false;
        private ulong                            current_time_block_changed_id = 0;
        private bool                             current_session_entered = false;
        private bool                             current_session_changed_frozen = false;
        private ulong                            current_session_notify_expiry_time_id = 0;
        private Pomodoro.Session?                previous_session = null;
        private Pomodoro.TimeBlock?              previous_time_block = null;
        private GLib.Settings?                   settings = null;
        private int                              resolving_timer_state = 0;
        private ulong                            timer_resolve_state_id = 0;
        private ulong                            timer_state_changed_id = 0;
        private ulong                            timer_finished_id = 0;
        private ulong                            timer_suspending_id = 0;
        private ulong                            timer_suspended_id = 0;
        private uint                             expiry_timeout_id = 0;
        private ulong                            scheduler_notify_session_template_id = 0;
        private uint                             reschedule_idle_id = 0;
        private uint                             active_watch_id = 0;

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
            this.timezone_monitor = new Pomodoro.TimeZoneMonitor ();
            this.timezone_history = new Pomodoro.TimezoneHistory ();

            this.settings.changed.connect (this.on_settings_changed);
            this.timezone_monitor.changed.connect (this.on_timezone_changed);

            this.update_session_template ();
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

        private int64 get_current_time ()
        {
            return this.resolving_timer_state > 0
                ? this._timer.get_last_state_changed_time ()
                : this._timer.get_current_time ();
        }

        private Pomodoro.Session initialize_next_session (int64 timestamp)
        {
            var session = new Pomodoro.Session ();

            this._scheduler.reschedule_session (session, null, timestamp);

            return session;
        }

        private Pomodoro.TimeBlock initialize_next_time_block (int64 timestamp)
        {
            Pomodoro.TimeBlock? next_time_block = null;
            Pomodoro.Session? next_session = null;

            if (this._current_time_block != null &&
                this._current_time_block.state == Pomodoro.State.LONG_BREAK &&
                !this._scheduler.is_time_block_completed (this._current_time_block, timestamp))
            {
                // Continue current session.
                // We don't have next pomodoro yet. It needs to be added by scheduler.
                next_time_block = null;
                next_session = this._current_session;
            }
            else {
                // Try getting a scheduled block.
                next_time_block = this.get_next_time_block ();
                next_session = next_time_block != null ? next_time_block.session : null;
            }

            // Discard session if it has expired.
            if (next_session != null &&
                next_session.is_expired (timestamp))
            {
                next_session = null;
            }

            // Reschedule - update time-blocks to given timestamp.
            if (next_session != null)
            {
                next_session.freeze_changed ();

                // Update break type. It's not done by scheduler, because we want to start a desired break at will.
                if (next_time_block != null && next_time_block.state.is_break ())
                {
                    var next_state = Pomodoro.State.BREAK;

                    if (!this._has_uniform_breaks) {
                        next_state = this.is_long_break_needed (timestamp)
                            ? Pomodoro.State.LONG_BREAK
                            : Pomodoro.State.SHORT_BREAK;
                    }

                    next_time_block.set_state_internal (next_state);
                }

                this.reschedule (next_session, next_time_block, timestamp);

                next_session.thaw_changed ();

                if (next_time_block == null) {
                    next_time_block = next_session == this._current_session
                        ? next_session.get_next_time_block (this._current_time_block)
                        : next_session.get_first_time_block ();
                }
            }

            if (next_session == null ||
                next_time_block == null)
            {
                next_session = this.initialize_next_session (timestamp);
                next_time_block = next_session.get_first_time_block ();
            }

            assert (next_time_block != null);
            assert (next_time_block.session == next_session);

            this.next_time_block = next_time_block;
            this.next_session = next_session;

            return next_time_block;
        }

        /**
         * Builds a `TimerState` according to current time-block.
         */
        private void initialize_timer_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            var current_time_block = this._current_time_block;

            // Adjust timer state according to current-time-block.
            if (current_time_block != null)
            {
                state.duration     = current_time_block.duration;
                state.user_data    = current_time_block;

                if (this.active_watch_id == 0) {
                    state.offset       = current_time_block.calculate_elapsed (timestamp);
                    state.started_time = current_time_block.start_time;
                }
                else {
                    state.offset       = 0;
                    state.started_time = Pomodoro.Timestamp.UNDEFINED;
                }
            }
            else {
                state = Pomodoro.TimerState ();
            }
        }

        private void update_session_template ()
        {
            this._scheduler.session_template = Pomodoro.SessionTemplate.with_defaults ();
        }

        private void update_timer_state (int64 timestamp)
        {
            if (this.resolving_timer_state != 0) {
                return;
            }

            if (this._current_time_block != null)
            {
                var state = Pomodoro.TimerState ();
                this.initialize_timer_state (ref state, timestamp);

                this._timer.set_state_full (state, timestamp);
            }
            else {
                this._timer.reset (0, null, timestamp);
            }
        }

        private void update_has_uniform_breaks ()
        {
            var has_uniform_breaks = this._scheduler.session_template.has_uniform_breaks ();

            if (has_uniform_breaks != this._has_uniform_breaks)
            {
                this._has_uniform_breaks = has_uniform_breaks;

                this.notify_property ("has-uniform-breaks");
            }

            if (this._current_time_block != null &&
                this._current_time_block.state == Pomodoro.State.BREAK &&
                !has_uniform_breaks)
            {
                this._current_time_block.set_state_internal (Pomodoro.State.SHORT_BREAK);
            }

            if (this._current_time_block != null &&
                this._current_time_block.state == Pomodoro.State.SHORT_BREAK &&
                has_uniform_breaks)
            {
                this._current_time_block.set_state_internal (Pomodoro.State.BREAK);
            }
        }

        /**
         * Try reschedule current session.
         *
         * Passing the `timestamp` implies that we want to skip the current time-block. Not passing, implies
         * the current time-block will be finished according to schedule.
         */
        private void reschedule (Pomodoro.Session?   session = null,
                                 Pomodoro.TimeBlock? next_time_block = null,
                                 int64               timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (session == null) {
                session = this._current_session;
            }

            if (Pomodoro.Timestamp.is_undefined (timestamp))
            {
                var now = this.get_current_time ();
                timestamp = this._current_time_block != null
                    ? int64.max (now, this._current_time_block.end_time)
                    : now;
            }

            if (this.reschedule_idle_id != 0) {
                GLib.Source.remove (this.reschedule_idle_id);
                this.reschedule_idle_id = 0;
            }

            var last_gap = this._current_session == session && this._current_time_block != null
                ? this._current_time_block.get_last_gap ()
                : null;

            if (last_gap != null && Pomodoro.Timestamp.is_undefined (last_gap.end_time)) {
                return;  // Reschedule once user resumes the timer.
            }

            if (this._scheduler != null && session != null) {
                this._scheduler.reschedule_session (session, next_time_block, timestamp);
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

        /**
         * Set current time-block.
         *
         * It may ignore given session if it's completed.
         */
        private void set_current_time_block_full (Pomodoro.Session?   session,
                                                  Pomodoro.TimeBlock? time_block,
                                                  int64               timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (session == this._current_session && time_block == this._current_time_block) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            if (session != null && session.is_expired (timestamp)) {
                GLib.debug ("set_current_time_block_full: setting an expired session");
            }

            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;
            var previous_state      = this._current_state;
            var state               = time_block != null ? time_block.state : Pomodoro.State.STOPPED;

            this.freeze_current_session_changed ();

            // Leave previous time-block.
            if (previous_time_block != null)
            {
                // Prevent `TimeBlock.changed` signal from triggering rescheduling.
                if (this.current_time_block_changed_id != 0) {
                    GLib.SignalHandler.block (previous_time_block, this.current_time_block_changed_id);
                }

                if (previous_time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    this.mark_time_block_end (previous_time_block, timestamp);
                }

                if (this.current_time_block_entered) {
                    this.leave_time_block (previous_time_block);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    GLib.debug ("The time-block was changed during `leave-time-block` emission.");
                    return;
                }
            }

            if (session != null && session.is_completed ()) {
                session = null;
            }

            // Leave previous session.
            if (previous_session != null && session != previous_session)
            {
                this.mark_session_end (previous_session);

                if (this.current_session_entered) {
                    this.leave_session (previous_session);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    GLib.debug ("The time-block was changed during `leave-session` emission.");
                    return;
                }
            }

            // Run rescheduling to make sure the next time-block is up to date.
            // Skip rescheduling if time-block if session appears to be just populated.
            if (session != null && time_block != null && time_block.start_time != timestamp) {
                this.reschedule (session, time_block, timestamp);
            }
            else if (session != null && time_block == null) {
                this.reschedule (session, time_block, timestamp);
            }

            // Enter session.
            if (session != previous_session)
            {
                this.previous_session    = previous_session;
                this.previous_time_block = previous_time_block;
                this._current_session    = session;
                this._current_time_block = null;
                this._current_gap        = null;

                this.notify_property ("current-session");

                if (session != null) {
                    this.enter_session (session);
                }

                if (this._current_session != session) {
                    GLib.debug ("The session was changed during `enter-session` emission.");
                    return;
                }

                if (this._current_time_block != null) {
                    GLib.debug ("The time-block was changed during `enter-session` emission.");
                    return;
                }
            }

            // Enter time-block. It will start or stop the timer depending whether time-block is null.
            if (time_block != previous_time_block)
            {
                this.previous_time_block = previous_time_block;
                this._current_time_block = time_block;
                this._current_gap        = null;
                this._current_state      = state;

                this.notify_property ("current-time-block");

                if (state != previous_state) {
                    this.notify_property ("current-state");
                }

                if (time_block != null) {
                    this.enter_time_block (time_block);
                }

                if (this._current_time_block != time_block) {
                    GLib.debug ("The time-block was changed during `enter-time-block` emission.");
                    return;
                }

                this.update_timer_state (timestamp);
            }

            this.reschedule_if_queued ();

            this.advanced (session, time_block,
                           previous_session, previous_time_block);

            if (this._current_time_block != null) {
                this.enable_idle_monitor ();
            }
            else {
                this.disable_idle_monitor ();
            }

            this.thaw_current_session_changed ();
        }

        private unowned Pomodoro.TimeBlock? get_next_time_block ()
        {
            Pomodoro.TimeBlock? next_time_block = null;

            if (this._current_session != null && this._current_time_block == null)
            {
                if (this.previous_time_block != null &&
                    this.previous_time_block.session == this._current_session)
                {
                    next_time_block = this._current_session.get_next_time_block (this.previous_time_block);
                }
                else {
                    next_time_block = this._current_session.get_first_time_block ();
                }
            }
            else if (this._current_session != null)
            {
                next_time_block = this._current_session.get_next_time_block (this._current_time_block);
            }

            return next_time_block != null ? next_time_block : this.next_time_block;
        }

        /**
         * Return cycle associated with current_time_block.
         */
        public unowned Pomodoro.Cycle? get_current_cycle ()
        {
            var current_time_block = this._current_time_block != null
                ? this._current_time_block
                : this.previous_time_block;

            if (current_time_block == null || this._current_session == null) {
                return null;
            }

            var cycles = this._current_session.get_cycles ();
            unowned GLib.List<unowned Pomodoro.Cycle> link = cycles.first ();

            while (link != null)
            {
                if (link.data.contains (current_time_block)) {
                    return link.data;
                }

                link = link.next;
            }

            return null;
        }

        private Pomodoro.AdvancementMode resolve_advancement_mode (Pomodoro.State next_state,
                                                                   int64          timestamp)
                                                                   requires (this.idle_monitor != null)
        {
            // Pick appropriate advancement mode according to current state.
            var current_state = this._current_time_block != null
                      ? this._current_time_block.state
                      : Pomodoro.State.STOPPED;
            var advancement_mode = Pomodoro.AdvancementMode.CONTINUOUS;

            if (current_state == Pomodoro.State.POMODORO) {
                advancement_mode = this.settings.get_boolean ("confirm-starting-break")
                        ? Pomodoro.AdvancementMode.MANUAL
                        : Pomodoro.AdvancementMode.CONTINUOUS;
            }
            else if (current_state.is_break ()) {
                advancement_mode = this.settings.get_boolean ("confirm-starting-pomodoro")
                        ? Pomodoro.AdvancementMode.MANUAL
                        : Pomodoro.AdvancementMode.WAIT_FOR_ACTIVITY;
            }

            switch (advancement_mode)
            {
                case Pomodoro.AdvancementMode.CONTINUOUS:
                    // Confirm advancement if user is idle at the end of a pomodoro.
                    // TODO: only do this if notifications have actions / have indicator
                    // TODO: perhaps we need to add option to the notification to rewind to the last activity
                    if (this._timer.is_finished () &&
                        this.idle_monitor.enabled &&
                        this.idle_monitor.is_idle (CONTINOUS_ADVANCEMENT_IDLE_TIME_LIMIT))
                    {
                        advancement_mode = Pomodoro.AdvancementMode.MANUAL;
                    }
                    break;

                case Pomodoro.AdvancementMode.WAIT_FOR_ACTIVITY:
                    // If `IdleMonitor` is not available, use manual confirmation.
                    if (!this.idle_monitor.enabled) {
                        advancement_mode = Pomodoro.AdvancementMode.MANUAL;
                    }
                    break;

                default:
                    break;
            }

            return advancement_mode;
        }

        /**
         * Push the removal of extra time-blocks onto SQLite queue.
         */
        private void delete_time_blocks (Gom.Repository    repository,
                                         int64             session_id,
                                         GLib.Array<int64> time_block_ids_to_keep)
                                         requires (session_id != 0)
        {
            var adapter = repository.adapter;
            assert (adapter != null);

            var session_id_value = GLib.Value (typeof (int64));
            session_id_value.set_int64 (session_id);

            Gom.Filter[] filters = {
                new Gom.Filter.eq (typeof (Pomodoro.TimeBlockEntry),
                                          "session-id",
                                          session_id_value),
            };

            for (var index = 0; index < time_block_ids_to_keep.length; index++)
            {
                var time_block_id = time_block_ids_to_keep.index (index);
                var time_block_id_value = GLib.Value (typeof (int64));
                time_block_id_value.set_int64 (time_block_id);

                filters += new Gom.Filter.neq (typeof (Pomodoro.TimeBlockEntry),
                                               "id",
                                               time_block_id_value);
            }

            var filter = new Gom.Filter.and_full (filters);
            var command_builder = (Gom.CommandBuilder) GLib.Object.@new (
                typeof (Gom.CommandBuilder),
                resource_type: typeof (Pomodoro.TimeBlockEntry),
                adapter: adapter,
                filter: filter);
            var command = command_builder.build_delete ();

            command.@ref ();

            adapter.queue_write (
                () => {
                    try {
                        command.execute (null);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while deleting time-blocks: %s", error.message);
                    }

                    command.@unref ();
                });
        }

        private void delete_gaps (Gom.Repository    repository,
                                  int64             time_block_id,
                                  GLib.Array<int64> gap_ids_to_keep)
                                  requires (time_block_id != 0)
        {
            var adapter = repository.adapter;
            assert (adapter != null);

            var time_block_id_value = GLib.Value (typeof (int64));
            time_block_id_value.set_int64 (time_block_id);

            Gom.Filter[] filters = {
                new Gom.Filter.eq (typeof (Pomodoro.GapEntry),
                                          "time-block-id",
                                          time_block_id_value),
            };

            for (var index = 0; index < gap_ids_to_keep.length; index++)
            {
                var gap_id = gap_ids_to_keep.index (index);
                var gap_id_value = GLib.Value (typeof (int64));
                gap_id_value.set_int64 (gap_id);

                filters += new Gom.Filter.neq (typeof (Pomodoro.GapEntry),
                                               "id",
                                               gap_id_value);
            }

            var filter = new Gom.Filter.and_full (filters);
            var command_builder = (Gom.CommandBuilder) GLib.Object.@new (
                typeof (Gom.CommandBuilder),
                resource_type: typeof (Pomodoro.GapEntry),
                adapter: adapter,
                filter: filter);
            var command = command_builder.build_delete ();

            command.@ref ();

            adapter.queue_write (
                () => {
                    try {
                        command.execute (null);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while deleting gaps: %s", error.message);
                    }

                    command.@unref ();
                });
        }

        private async void save_session (Gom.Repository   repository,
                                         Pomodoro.Session session)
                                         throws GLib.Error
        {
            if (!session.should_create_entry ())
            {
                if (session.entry != null && session.entry.id != 0)
                {
                    var session_entry = session.entry;
                    session.unset_entry ();

                    yield session_entry.delete_async ();
                }

                return;
            }

            // Collect session data.
            var is_updating_session_entry = session.should_update_entry ();
            var session_entry = is_updating_session_entry
                ? session.create_or_update_entry ()
                : session.entry;

            Pomodoro.TimeBlockEntry[] time_block_entries_array = {};
            Pomodoro.GapEntry[] gap_entries_array = {};

            var keep_time_block_ids = new GLib.Array<int64> ();
            var keep_gap_ids = new GLib.HashTable<int64?, GLib.Array> (GLib.direct_hash,
                                                                       GLib.direct_equal);

            session.@foreach (
                (time_block) => {
                    if (!time_block.should_create_entry ()) {
                        return;
                    }

                    var time_block_entry = time_block.entry;

                    if (time_block_entry != null && time_block_entry.get_is_from_table ()) {
                        keep_time_block_ids.append_val (time_block_entry.id);
                    }

                    if (time_block.should_update_entry ())
                    {
                        var gap_ids = new GLib.Array<int64> ();

                        time_block_entry = time_block.create_or_update_entry ();
                        time_block_entries_array += time_block_entry;
                        time_block.foreach_gap (
                            (gap) => {
                                if (!gap.should_create_entry ()) {
                                    return;
                                }

                                var gap_entry = gap.entry;

                                if (gap_entry != null && gap_entry.get_is_from_table ()) {
                                    gap_ids.append_val (gap_entry.id);
                                }

                                if (gap.should_update_entry ()) {
                                    gap_entry = gap.create_or_update_entry ();
                                    gap_entries_array += gap_entry;
                                }
                            });

                        if (time_block_entry.get_is_from_table ()) {
                            keep_gap_ids.insert (time_block_entry.id, gap_ids);
                        }
                    }
                });

            // Commit updates.
            try {
                if (is_updating_session_entry) {
                    yield session_entry.save_async ();
                }

                var time_block_entries = (Gom.ResourceGroup) GLib.Object.@new (
                        typeof (Gom.ResourceGroup),
                        repository: repository,
                        resource_type: typeof (Pomodoro.TimeBlockEntry),
                        is_writable: true);

                foreach (var time_block_entry in time_block_entries_array)
                {
                    assert (time_block_entry.session_id != 0);

                    // HACK: gom is eager to erase is-from-table flag,
                    //       which leads entries to being inserted again not updated
                    time_block_entry.set_data<bool> ("is-from-table", time_block_entry.id != 0);

                    time_block_entries.append (time_block_entry);
                }

                this.delete_time_blocks (repository,
                                         session_entry.id,
                                         keep_time_block_ids);
                time_block_entries.write_sync ();
                // yield time_block_entries.write_async ();  // XXX: should use async

                // HACK: Tell gom that entries are from db
                foreach (var time_block_entry in time_block_entries_array) {
                    time_block_entry.set_data<bool> ("is-from-table", true);
                }

                var gap_entries = (Gom.ResourceGroup) GLib.Object.@new (
                        typeof (Gom.ResourceGroup),
                        repository: repository,
                        resource_type: typeof (Pomodoro.TimeBlockEntry),
                        is_writable: true);

                foreach (var gap_entry in gap_entries_array) {
                    assert (gap_entry.time_block_id != 0);
                    gap_entries.append (gap_entry);
                }

                keep_gap_ids.@foreach (
                    (time_block_id, gap_ids) => {
                        this.delete_gaps (repository,
                                          time_block_id,
                                          gap_ids);
                    });
                gap_entries.write_sync ();
                // yield gap_entries.write_async ();  // XXX: should use async
            }
            catch (GLib.Error error) {
                throw error;
            }

            // TODO: check if instances are disposed properly
        }

        /**
         * Save session state to database.
         */
        public async bool save ()
        {
            var repository = Pomodoro.Database.get_repository ();
            assert (repository != null);

            var remaining_sessions = 0;
            var success = true;

            if (this.previous_session != null)
            {
                remaining_sessions++;

                this.save_session.begin (
                    repository,
                    this.previous_session,
                    (obj, res) => {
                        try {
                            this.save_session.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while saving previous session: %s", error.message);
                            success = false;
                        }

                        remaining_sessions--;

                        if (remaining_sessions == 0) {
                            this.save.callback ();
                        }
                    });
            }

            if (this._current_session != null)
            {
                remaining_sessions++;

                this.save_session.begin (
                    repository,
                    this._current_session,
                    (obj, res) => {
                        try {
                            this.save_session.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while saving current session: %s", error.message);
                            success = false;
                        }

                        remaining_sessions--;

                        if (remaining_sessions == 0) {
                            this.save.callback ();
                        }
                    });
            }

            if (remaining_sessions > 0) {
                yield;
            }

            return success;
        }

        /**
         * Restore session from database.
         */
        public async void restore () throws GLib.Error
        {
            // XXX: We're trying to write a timezone entry at first opportunity after the
            //      database is ready. Not the best place to do that.
            this.mark_timezone (this.timezone_monitor.timezone);

            // TODO
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
            // TODO: allow to count overdue time - count beyond finished_time
            var has_finished = this._timer.user_data == time_block && this._timer.is_finished ();
            var end_time = has_finished ? this._timer.state.finished_time : timestamp;

            time_block.freeze_changed ();
            time_block.end_time = end_time;
            time_block.foreach_gap (
                (gap) => {
                    gap.end_time = Pomodoro.Timestamp.is_undefined (gap.end_time)
                        ? end_time
                        : int64.min (gap.end_time, end_time);
                }
            );

            this.update_time_block_meta (time_block);
            time_block.set_status (this._scheduler.is_time_block_completed (time_block, time_block.end_time)
                                   ? Pomodoro.TimeBlockStatus.COMPLETED
                                   : Pomodoro.TimeBlockStatus.UNCOMPLETED);

            time_block.thaw_changed ();
        }

        /**
         * Discard time-blocks that were not marked as ended.
         * Time block that was in-progress should be marked
         */
        private void mark_session_end (Pomodoro.Session session)
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

        private void mark_timezone (GLib.TimeZone timezone,
                                    int64         timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.timezone_history.insert (timestamp, timezone);
        }

        private bool is_long_break_needed (int64 timestamp)
        {
            Pomodoro.SchedulerContext context;

            if (this._current_session == null) {
                return false;
            }

            this._scheduler.build_scheduler_context (this._current_session, timestamp, out context, null);

            return context.needs_long_break;
        }

        /**
         * Start given time-block.
         *
         * It ends previous time-block and switches to a new one, even if it's of same state.
         * It's works exactly like `set_current_time_block()`, but with a timestamp.
         *
         * The type of break may be changed during rescheduling.
         */
        private void advance_to_time_block (Pomodoro.TimeBlock? time_block,
                                            int64               timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var session = time_block != null ? time_block.session : this._current_session;

            if (time_block != null && session != null && session.is_expired (timestamp)) {
                GLib.warning ("Advancing to a time-block of expired session.");
            }

            this.set_current_time_block_full (session, time_block, timestamp);
        }

        /**
         * Switch to a given state.
         *
         * Unlike `advance_to_time_block()`, it tries to extend current time-block and can handle Pomodoro.State.BREAK.
         * This is the preferred method of advancing the timer states as it tries to avoid emitting enter- leave-
         * signals unnecessarily. Switching between break types will cause creation a of a new time-block.
         *
         * This method allows you to force a short or long break.
         */
        public void advance_to_state (Pomodoro.State state,
                                      int64          timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (state == Pomodoro.State.STOPPED) {
                this.advance_to_time_block (null, timestamp);
                return;
            }

            // Determine the type of break if Pomodoro.State.BREAK is given.
            // It's not efficient, as we build scheduler context again later.
            if (state == Pomodoro.State.BREAK && !this._has_uniform_breaks) {
                state = this.is_long_break_needed (timestamp) ? Pomodoro.State.LONG_BREAK : Pomodoro.State.SHORT_BREAK;
            }

            // Extend current time-block if possible.
            if (this._current_time_block != null &&
                this._current_time_block.state == state)
            {
                this.extend_current_time_block (timestamp);
                return;
            }

            // Check whether session has expired and select upcoming time-block.
            var next_time_block = this.get_next_time_block ();
            var next_session = next_time_block != null ? next_time_block.session : null;

            if (next_session == null || next_session.is_expired (timestamp)) {
                next_session = this.initialize_next_session (timestamp);
                next_time_block = next_session.get_first_time_block ();
            }

            next_session.freeze_changed ();

            // Create a time-block for given state.
            if (next_time_block != null && next_time_block.state != state) {
                var time_block = new Pomodoro.TimeBlock (state);
                next_session.insert_before (time_block, next_time_block);
                next_time_block = time_block;
            }
            else if (next_time_block == null) {
                var time_block = new Pomodoro.TimeBlock (state);
                next_session.append (time_block);
                next_time_block = time_block;
            }

            this.advance_to_time_block (next_time_block, timestamp);

            next_session.thaw_changed ();
        }

        /**
         * Jump to next scheduled time-block.
         */
        public void advance (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_current_session_changed ();

            var next_time_block = this.initialize_next_time_block (timestamp);

            this.advance_to_time_block (next_time_block, timestamp);
        }

        /**
         * Update session `expiry-time`.
         *
         * The given timeout is relative to last action in the session.
         */
        private void bump_expiry_time (int64 timeout)
        {
            if (this.expiry_timeout_id != 0)
            {
                GLib.Source.remove (this.expiry_timeout_id);
                this.expiry_timeout_id = 0;
            }

            if (this._current_session != null && !this._current_session.is_scheduled ())
            {
                var expiry_time = Pomodoro.Timestamp.UNDEFINED;
                var current_or_previous_time_block = this._current_time_block != null
                    ? this._current_time_block
                    : this.previous_time_block;

                if (this._timer.is_finished ()) {
                    expiry_time = this.timer.state.finished_time + timeout;
                }
                else if (this._timer.is_paused ()) {
                    expiry_time = this._timer.state.paused_time + timeout;
                }
                else if (this._timer.is_started ()) {
                    expiry_time = this._timer.state.started_time + this._timer.state.duration + timeout;
                }
                else if (current_or_previous_time_block != null &&
                         current_or_previous_time_block.get_status () != Pomodoro.TimeBlockStatus.SCHEDULED) {
                    expiry_time = current_or_previous_time_block.end_time + timeout;
                }

                GLib.SignalHandler.block (this._current_session, this.current_session_notify_expiry_time_id);
                this._current_session.expiry_time = expiry_time;
                GLib.SignalHandler.unblock (this._current_session, this.current_session_notify_expiry_time_id);

                // Notify signal may not kick in if there is no change. Therefore we trigger it manually.
                this.on_current_session_notify_expiry_time ();
            }
        }

        private void expire_current_session (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this._current_session == null) {
                return;
            }

            if (Pomodoro.Timestamp.is_undefined (timestamp)) {
                timestamp = this._current_session.expiry_time;
            }

            var previous_session = this._current_session;

            this.session_expired (this._current_session, timestamp);

            if (this._current_session != previous_session) {
                GLib.debug ("The session was changed during `session-expired` emission.");
            }
            else {
                this.reset (timestamp);
            }
        }

        private void freeze_current_session_changed ()
        {
            if (this._current_session != null && !this.current_session_changed_frozen)
            {
                this.current_session_changed_frozen = true;
                this._current_session.freeze_changed ();

                // TODO schedule unfreeze; keep `Session.changed` signal frozen until session is rescheduled
                // this.session_changed_idle_id = GLib.Idle.add (
                //     () => {
                //         this.session_changed_idle_id = 0;
                //         this.thaw_current_session_changed ();
                //
                //         return GLib.Source.REMOVE;
                //     },
                //     GLib.Priority.HIGH
                // );
            }
        }

        private void thaw_current_session_changed ()
        {
            if (this.current_session_changed_frozen)
            {
                assert (this._current_session != null);

                this.current_session_changed_frozen = false;
                this._current_session.thaw_changed ();
            }
        }

        private bool should_auto_pause ()
        {
            if (this._current_time_block == null ||
                this._current_time_block.state != Pomodoro.State.POMODORO ||
                !this._timer.is_running ())
            {
                return false;
            }

            if (this.lockscreen != null && this.lockscreen.enabled && this.lockscreen.active) {
                return true;
            }

            if (this.screensaver != null && this.screensaver.enabled && this.screensaver.active) {
                return true;
            }

            return false;
        }

        private void pause ()
        {
            if (!this.auto_paused) {
                this.auto_paused = true;
                this._timer.pause ();
            }
        }

        private void resume ()
        {
            if (this.auto_paused) {
                this.auto_paused = false;
                this._timer.resume ();
            }
        }

        private void enable_auto_pause ()
        {
            if (this.lockscreen == null) {
                this.lockscreen = new Pomodoro.LockScreen ();
                this.lockscreen.notify["active"].connect (this.on_lockscreen_notify_active);
            }

            if (this.screensaver == null) {
                this.screensaver = new Pomodoro.ScreenSaver ();
                this.screensaver.notify["active"].connect (this.on_screensaver_notify_active);
            }

            if (this.should_auto_pause ()) {
                this.pause ();
            }
        }

        private void disable_auto_pause ()
        {
            if (this.lockscreen != null) {
                this.lockscreen.notify["active"].disconnect (this.on_lockscreen_notify_active);
                this.lockscreen = null;
            }

            if (this.screensaver != null) {
                this.screensaver.notify["active"].disconnect (this.on_screensaver_notify_active);
                this.screensaver = null;
            }

            this.resume ();
        }

        private void update_auto_pause ()
        {
            if (this._current_time_block != null && this.settings.get_boolean ("pause-on-lockscreen")) {
                this.enable_auto_pause ();
            }
            else {
                this.disable_auto_pause ();
            }
        }

        private void update_time_block_meta (Pomodoro.TimeBlock time_block)
        {
            var completion_time = this._scheduler.calculate_time_block_completion_time (current_time_block);
            current_time_block.set_completion_time (completion_time);

            var weight = this._scheduler.calculate_time_block_weight (current_time_block);
            current_time_block.set_weight (weight);
        }

        /**
         * Update time-block according to changes in timer state.
         */
        private void update_current_time_block (Pomodoro.TimerState current_state,
                                                Pomodoro.TimerState previous_state,
                                                int64               timestamp)
                                                requires (current_state.user_data == this._current_time_block)
                                                requires (this._current_time_block != null)
                                                requires (Pomodoro.Timestamp.is_defined (timestamp))
        {
            var previous_time_block = this.previous_time_block;
            var current_time_block = this._current_time_block;

            this.freeze_current_session_changed ();

            // Handle waiting for an activity and overdue time after confirmation.
            var waiting_for_activity = current_state.user_data == previous_state.user_data &&
                                       current_state.is_started () &&
                                       !previous_state.is_started ();

            var confirmed_advance = current_state.user_data != previous_state.user_data &&
                                       current_state.is_started () &&
                                       previous_state.is_finished ();
            if (waiting_for_activity || confirmed_advance)
            {
                if (previous_time_block != null) {
                    previous_time_block.end_time += int64.min (
                                        current_state.started_time - previous_time_block.end_time,
                                        OVERDUE_TIMEOUT);
                }
                else {
                    GLib.warning ("Unable to extend the duration of previous time-block.");
                }

                // TODO: add gap in between?
                current_time_block.move_to (current_state.started_time);
            }

            // Handle duration change.
            current_time_block.end_time = current_state.is_started ()
                ? current_state.started_time + current_state.offset + current_state.duration
                : current_time_block.start_time + current_state.offset + current_state.duration;

            if (current_state.user_data == previous_state.user_data &&
                current_state.paused_time == previous_state.paused_time &&
                current_state.offset != previous_state.offset)
            {
                // Handle rewind.
                var interval = current_state.offset - previous_state.offset;
                var gap = new Pomodoro.Gap ();
                gap.end_time = this._current_gap != null ? this._current_gap.start_time : timestamp;
                gap.start_time = int64.max (Pomodoro.Timestamp.subtract_interval (gap.end_time, interval),
                                            current_time_block.start_time);
                current_time_block.add_gap (gap);
                current_time_block.normalize_gaps (timestamp);
            }
            else if (current_state.is_paused ())
            {
                // Mark pause start.
                if (this._current_gap == null) {
                    this._current_gap = new Pomodoro.Gap.with_start_time (current_state.paused_time);
                    this._current_time_block.add_gap (this._current_gap);
                }
                else {
                    if (this._current_gap.start_time != current_state.paused_time) {
                        GLib.warning ("Gap.start_time does not match with TimerState.paused_time.");
                    }
                }
            }
            else {
                // Mark pause end.
                if (this._current_gap != null) {
                    this._current_gap.end_time = timestamp;
                    this._current_gap = null;
                }
            }

            this.update_time_block_meta (current_time_block);
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
            // Timer is paused or has finished. Nothing to resolve.
            // Advancing to a next time-block is handled after emitting `Timer.state_changed`.
            if (state.is_finished () || state.is_paused ()) {
                return;
            }

            // Waiting for activity.
            // `SessionManager` already set up everything in place. Update the timer state.
            if (!state.is_started () && state.user_data == this._current_time_block && this.active_watch_id != 0) {
                return;
            }

            // Stopping (resetting) the timer.
            // Adjust state as if the timer has already stopped. Handling will be continued in `Timer.state_changed`.
            if (!state.is_started ())
            {
                this.advance_to_time_block (null, timestamp);
                this.initialize_timer_state (ref state, timestamp);
                return;
            }

            // Timer is started by a session manager.
            if (state.user_data == this._current_time_block && this._current_time_block != null) {
                return;
            }

            // Start the timer with a new session.
            if (this._current_session != null && this._current_session.is_expired (timestamp))
            {
                this.advance (state.started_time);
                this.initialize_timer_state (ref state, timestamp);
                return;
            }

            // Starting the timer.
            if (this._current_time_block == null)
            {
                this.advance_to_state (Pomodoro.State.POMODORO, state.started_time);
                this.initialize_timer_state (ref state, timestamp);
                return;
            }
        }

        private void on_timer_resolve_state (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
                                             requires (state.user_data == null ||
                                                       state.user_data == this._current_time_block)
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
            // Remove activity watch upon first change.
            if (this.active_watch_id != 0 && (current_state.is_started () || current_state.user_data == null)) {
                this.idle_monitor.remove_watch (this.active_watch_id);
                this.active_watch_id = 0;
            }

            // HACK: Use `resolving_timer_state` to preserve original timestamp
            //       in `on_current_session_notify_expiry_time()`.
            this.resolving_timer_state++;
            this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
            this.update_auto_pause ();
            this.reschedule_if_queued ();
            this.thaw_current_session_changed ();
            this.resolving_timer_state--;
        }

        private void on_timer_finished (Pomodoro.TimerState state)
                                        requires (this.idle_monitor != null)

        {
            this.freeze_current_session_changed ();

            var timestamp        = state.finished_time;
            var next_time_block  = this.initialize_next_time_block (timestamp);
            var advancement_mode = this.resolve_advancement_mode (next_time_block.state, timestamp);

            switch (advancement_mode)
            {
                case Pomodoro.AdvancementMode.CONTINUOUS:
                    if (this.active_watch_id != 0) {
                        this.idle_monitor.remove_watch (this.active_watch_id);
                        this.active_watch_id = 0;
                    }

                    this.advance_to_time_block (next_time_block, timestamp);
                    break;

                case Pomodoro.AdvancementMode.WAIT_FOR_ACTIVITY:
                    // Jump to a next time-block and start the timer after detecting user activity.
                    // It has only one use case: after a break, when we're certain we want to start pomodoro next.
                    // `active_watch_id != 0` will indicate that we're waiting for activity.
                    if (this.active_watch_id == 0) {
                        this.active_watch_id = this.idle_monitor.add_active_watch (this.on_became_active);
                    }

                    this.advance_to_time_block (next_time_block, timestamp);
                    break;

                case Pomodoro.AdvancementMode.MANUAL:
                    // Keep the current time-block and let the timer indicate it has finished
                    // until user confirms the advancement. Use it if you're uncertain whether the current state
                    // should be extended.
                    if (this.active_watch_id != 0) {
                        this.idle_monitor.remove_watch (this.active_watch_id);
                        this.active_watch_id = 0;
                    }

                    this.confirm_advancement (this._current_time_block, next_time_block);
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void on_timer_suspending (int64 start_time)
        {
            if (this._current_gap != null)
            {
                this._current_gap.end_time = start_time;
                this._current_gap = null;
            }

            if (this._current_time_block != null)
            {
                this._current_gap = new Pomodoro.Gap.with_start_time (start_time);  // TODO: mark gap as SLEEP
                this._current_time_block.add_gap (this._current_gap);
            }

            if (this._current_session != null)
            {
                GLib.SignalHandler.block (this._current_session, this.current_session_notify_expiry_time_id);
                this._current_session.expiry_time = start_time + SESSION_EXPIRY_TIMEOUT;
                GLib.SignalHandler.unblock (this._current_session, this.current_session_notify_expiry_time_id);
            }

            if (this.expiry_timeout_id != 0)
            {
                GLib.Source.remove (this.expiry_timeout_id);
                this.expiry_timeout_id = 0;
            }
        }

        private void on_timer_suspended (int64 start_time,
                                         int64 end_time)
        {
            if (this._current_session != null)
            {
                if (this._current_session.is_expired (end_time)) {
                    this.expire_current_session (end_time);
                }
                else {
                    this.bump_expiry_time (SESSION_EXPIRY_TIMEOUT);
                }
            }
        }

        private void on_current_time_block_changed (Pomodoro.TimeBlock time_block)
        {
            if (this.resolving_timer_state == 0) {
                this._scheduler.reschedule_session (this._current_session, null, this.get_current_time ());
            }
            else {
                this.queue_reschedule ();
            }

            if (this._current_state != time_block.state) {
                this._current_state = time_block.state;
                this.notify_property ("current-state");
            }
        }

        private void on_scheduler_notify_session_template ()
        {
            this.update_has_uniform_breaks ();
            this.queue_reschedule ();
        }

        private void handle_became_active ()
        {
            if (this._timer.user_data == null || this._timer.is_started ()) {
                return;
            }

            if ((this.screensaver != null && this.screensaver.active) ||
                (this.lockscreen != null && this.lockscreen.active))
            {
                return;
            }

            this._timer.start ();
        }

        private void on_lockscreen_notify_active (GLib.Object    object,
                                                  GLib.ParamSpec pspec)
        {
            if (this.should_auto_pause ()) {
                this.pause ();
            }
            else {
                this.resume ();
            }

            if (!this.lockscreen.active) {
                this.handle_became_active ();
            }
        }

        private void on_screensaver_notify_active (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            if (this.should_auto_pause ()) {
                this.pause ();
            }
            else {
                this.resume ();
            }

            if (!this.screensaver.active) {
                this.handle_became_active ();
            }
        }

        private void on_became_active ()
        {
            this.active_watch_id = 0;

            this.handle_became_active ();
        }

        private void on_timezone_changed ()
        {
            this.mark_timezone (this.timezone_monitor.timezone);
        }

        /**
         * A wrapper for `Timeout.add_seconds`.
         *
         * We don't want expiry callback to increment the `SessionManager` reference counter, hence the static method
         * and the use of pointer.
         */
        private static uint setup_expiry_timeout (uint  seconds,
                                                  void* session_manager_ptr)
        {
            weak Pomodoro.SessionManager session_manager = (Pomodoro.SessionManager) session_manager_ptr;

            return GLib.Timeout.add_seconds (seconds,
                () => {
                    session_manager.expiry_timeout_id = 0;
                    session_manager.expire_current_session ();

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
                case "cycles":
                    this.update_session_template ();
                    break;

                case "pause-on-lockscreen":
                    this.update_auto_pause ();
                    break;

                case "pomodoro-advancement-mode":
                case "break-advancement-mode":
                    break;
            }
        }

        private void enable_idle_monitor ()
        {
            if (this.idle_monitor == null) {
                this.idle_monitor = new Pomodoro.IdleMonitor ();
            }
        }

        private void disable_idle_monitor ()
        {
            if (this.active_watch_id != 0) {
                this.idle_monitor.remove_watch (this.active_watch_id);
                this.active_watch_id = 0;
            }

            this.idle_monitor = null;
        }

        /**
         * Initialize session if there is no current session or if it expired.
         */
        public void ensure_session (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this._timer.is_running ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            if (this._current_session == null || this._current_session.is_expired (timestamp))
            {
                var next_time_block = this.initialize_next_session (timestamp);

                this.set_current_time_block_full (next_time_block, null, timestamp);
            }
        }

        /**
         * Start a new session. The timestamp marks the end time of ongoing session.
         */
        public void reset (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            var now = Pomodoro.Timestamp.from_now ();

            if (Pomodoro.Timestamp.is_undefined (timestamp)) {
                timestamp = now;
            }

            if (this._current_session != null && !this._current_session.is_scheduled ())
            {
                var next_time_block = this.initialize_next_session (now);

                this.set_current_time_block_full (next_time_block, null, timestamp);
            }
        }

        public void check_current_session_expired ()
        {
            var timestamp = Pomodoro.Timestamp.from_now ();

            if (this._current_session != null && this._current_session.is_expired (timestamp)) {
                this.expire_current_session (timestamp);
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
            this.current_session_notify_expiry_time_id = this._current_session.notify["expiry-time"].connect (
                    this.on_current_session_notify_expiry_time);

            this.update_has_uniform_breaks ();
        }

        [Signal (run = "first")]
        public signal void leave_session (Pomodoro.Session session)
        {
            assert (session == this._current_session);

            this.thaw_current_session_changed ();

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
                GLib.warning ("`TimeBlock.changed` signal handler has not been disconnected properly");
            }

            this.current_time_block_entered = true;
            this.current_time_block_changed_id = time_block.changed.connect (this.on_current_time_block_changed);
            this.next_time_block = null;
            this.next_session = null;

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

        public signal void session_expired (Pomodoro.Session session,
                                            int64            timestamp)
        {
            GLib.debug ("Session expired");
        }

        /**
         * Outward signal that we need a confirmation before advancing to a next time-block.
         * Until then the timer will indicate that it has finished, the session-manager will keep current time-block
         * intact. You should use skip action or `.advance()` to jump to the next time-block.
         */
        public signal void confirm_advancement (Pomodoro.TimeBlock current_time_block,
                                                Pomodoro.TimeBlock next_time_block);

        /**
         * A convenience signal to handle transition between time-blocks.
         *
         * It's emitted after entering the current_time_block.
         */
        public signal void advanced (Pomodoro.Session?   current_session,
                                     Pomodoro.TimeBlock? current_time_block,
                                     Pomodoro.Session?   previous_session,
                                     Pomodoro.TimeBlock? previous_time_block);

        public override void dispose ()
        {
            if (Pomodoro.SessionManager.instance == this) {
                Pomodoro.SessionManager.instance = null;
            }

            if (this._timer != null)
            {
                if (this.timer_resolve_state_id != 0) {
                    this._timer.disconnect (this.timer_resolve_state_id);
                    this.timer_resolve_state_id = 0;
                }

                if (this.timer_state_changed_id != 0) {
                    this._timer.disconnect (this.timer_state_changed_id);
                    this.timer_state_changed_id = 0;
                }

                if (this.timer_finished_id != 0) {
                    this._timer.disconnect (this.timer_finished_id);
                    this.timer_finished_id = 0;
                }

                if (this.timer_suspending_id != 0) {
                    this._timer.disconnect (this.timer_suspending_id);
                    this.timer_suspending_id = 0;
                }

                if (this.timer_suspended_id != 0) {
                    this._timer.disconnect (this.timer_suspended_id);
                    this.timer_suspended_id = 0;
                }
            }

            if (this._scheduler != null)
            {
                if (this.scheduler_notify_session_template_id != 0) {
                    this._scheduler.disconnect (this.scheduler_notify_session_template_id);
                    this.scheduler_notify_session_template_id = 0;
                }
            }

            if (this.settings != null) {
                this.settings.changed.disconnect (this.on_settings_changed);
            }

            if (this.reschedule_idle_id != 0) {
                GLib.Source.remove (this.reschedule_idle_id);
                this.reschedule_idle_id = 0;
            }

            if (this.expiry_timeout_id != 0) {
                GLib.Source.remove (this.expiry_timeout_id);
                this.expiry_timeout_id = 0;
            }

            this.disable_auto_pause ();
            this.disable_idle_monitor ();

            this.settings = null;
            this._current_gap = null;
            this._current_time_block = null;
            this._current_session = null;
            this.next_time_block = null;
            this.next_session = null;
            this._timer = null;
            this._scheduler = null;
            this.idle_monitor = null;
            this.timezone_monitor = null;
            this.timezone_history = null;
            this.lockscreen = null;
            this.screensaver = null;

            base.dispose ();
        }
    }
}
