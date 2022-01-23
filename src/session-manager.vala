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


        /**
         * A current session.
         *
         * After idle time or when timer is stopped it's still kept as current. You need to check if it hasn't expired.
         */
        [CCode(notify = false)]
        public unowned Pomodoro.Session current_session {
            get {
                return this._current_session;
            }
            set {
                if (this._current_session == value) {
                    return;
                }

                this.set_current_time_block_internal (
                    value,
                    value != null ? value.get_first_time_block () : null);
            }
        }

        /**
         * Current time-block.
         *
         * `Session` alone is not aware which time-block is current, only `SessionManager`. Current time-block
         * is reflected in `Timer.state`, but only if `Timer.state.user_data == this.current_time_block`. It's allowed
         * for the timer to have `Timer.state.user_data == null`, which means the timer is stopped.
         *
         * Setting to `null` means that current session has not yet started.
         *
         * Time-block must be assigned to a session beforehand. Setting a time-block with a different session will
         * change current session too. All blocks within such session preceding given `time-block` will be removed.
         */
        [CCode(notify = false)]
        public unowned Pomodoro.TimeBlock current_time_block {
            get {
                return this._current_time_block;
            }
            set {
                assert (value == null || value.session != null);

                if (this._current_time_block == value) {
                    return;
                }

                this.set_current_time_block_internal (
                    value != null ? value.session : this._current_session,
                    value);
            }
        }

        private Pomodoro.TimeBlock? _current_time_block = null;
        private Pomodoro.Session?   _current_session = null;
        private int                 block_timer_signal_handlers_count = 0;
        private bool                current_time_block_entered = false;
        private bool                current_session_entered = false;
        // private Pomodoro.State      _current_state = Pomodoro.State.UNDEFINED;
        // private Pomodoro.TimeBlock? previous_time_block = null;
        // private Pomodoro.Session?   previous_session = null;
        // private bool             has_pending_enter_session_signal = false;
        // private bool             has_pending_enter_time_block_signal = false;

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
            this.timer.resolve_state.connect (this.on_timer_resolve_state);
            this.timer.state_changed.connect (this.on_timer_state_changed);
            // this.timer.state_changed.connect_after (this.on_timer_state_changed_after);
            this.timer.suspended.connect (this.on_timer_suspended);
        }

        ~SessionManager ()
        {
            if (Pomodoro.SessionManager.instance == null) {
                Pomodoro.SessionManager.instance = null;
            }

            // TODO: disconnect timer signals
        }


        private void set_current_time_block_internal (Pomodoro.Session?   session,
                                                      Pomodoro.TimeBlock? time_block)
                                                      requires (session != null || (session == null && time_block == null))
        {
            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;

            if (previous_time_block != null) {
                if (this.current_time_block_entered) {
                    this.current_time_block_entered = false;
                    this.leave_time_block (previous_time_block);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    // a different time-block was set during `leave_time_block()` emission
                    return;
                }
            }

            if (previous_session != null && previous_session != session) {
                if (this.current_session_entered) {
                    this.current_session_entered = false;
                    this.leave_session (previous_session);
                }

                if (this._current_time_block != previous_time_block || this._current_session != previous_session) {
                    // a different time-block was set during `leave_session()` emission
                    return;
                }
            }

            if (time_block != null) {
                this.setup_timer ((timer) => {
                    timer.state = Pomodoro.TimerState () {
                        duration      = time_block.duration,
                        offset        = 0,
                        started_time  = Pomodoro.Timestamp.UNDEFINED,
                        paused_time   = Pomodoro.Timestamp.UNDEFINED,
                        finished_time = Pomodoro.Timestamp.UNDEFINED,
                        user_data     = time_block
                    };
                });
            }
            else {
                this.setup_timer ((timer) => {
                    timer.reset ();
                });
            }

            if (this._current_session == previous_session && previous_session != session)
            {
                if (previous_session != session) {
                    // this.previous_session = this._current_session;
                    this._current_session = session;

                    this.notify_property ("current-session");
                }

                if (session != null) {
                    this.current_session_entered = true;
                    this.enter_session (session);
                }
            }

            if (this._current_time_block == previous_time_block)
            {
                if (time_block != previous_time_block) {
                    // this.previous_time_block = this._current_time_block;
                    this._current_time_block = time_block;

                    this.notify_property ("current-time-block");
                }

                if (time_block != null) {
                    this.current_time_block_entered = true;
                    this.enter_time_block (time_block);
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




        // public void reset (int64 timestamp = -1)
        // {
            // TODO
        // }

        // private Pomodoro.Session resolve_next_session ()
        // {
        //     var next_session = new Pomodoro.Session.from_template ();

            // TODO: schedule time blocks

        //     return next_session;
        // }

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




        private void setup_timer (TimerContextFunc func)
                                  ensures (this.block_timer_signal_handlers_count >= 0)
        {
            this.block_timer_signal_handlers_count++;

            // TODO: we could block handlers https://valadoc.org/gobject-2.0/GLib.SignalHandler.html

            func (this.timer);

            this.block_timer_signal_handlers_count--;
        }





        // TODO: rename to advance_to_state ()

        private Pomodoro.Session initialize_session (int64 timestamp)
        {
            // TODO: in future we may want to align time-blocks according to agenda/scheduled events

            return new Pomodoro.Session.from_template (timestamp);
        }

        /**
         * Either pick scheduled block as current or initialize new session.
         */
        // private void prepare_current_time_block (Pomodoro.State state,
        //                                          int64          start_time)
        //                                          ensures (this._current_session != null &&
        //                                                   this._current_time_block != null)
        // {
        //     var session = this._current_session;
        //     var time_block = this._current_time_block;

            // Check if session hasn't expired. Create a new session if necessary.
        //     if (session != null && session.is_expired (start_time)) {
        //         session = null;
        //         time_block = null;
        //     }

        //     if (time_block != null && time_block.state == state) {
                // TODO extend current time-block, so that remaining time is 25 minutes
        //         assert_not_reached ();
                // TODO: return;
        //     }

            // Try to pick next POMODORO within session
        //     if (session == null) {
        //         session = new Pomodoro.Session.from_template (start_time);
        //         time_block = session.get_first_time_block ();
                // time_block = session.find_time_block (state, time_block);  // TODO
        //     }
        //     else {
                // TODO: Check if session can be completed,
                //       eg if we force POMODORO during a long break, it should start new session

                // TODO select next POMODORO from session, remove time_blocks between current_time_block and chosen one
        //         assert_not_reached ();
                // this.time_blocks.find (time_block);
        //     }

            // Append new POMODORO if there there is none scheduled
        //     if (time_block == null) {
        //         time_block = new Pomodoro.TimeBlock.with_start_time (state, start_time);

        //         session.insert_after (time_block, this._current_time_block);
        //     }

        //     if (this._current_time_block != null) {
        //         this._current_time_block.end_time = int64.min (this._current_time_block.end_time,
        //                                                        time_block.start_time);
        //     }

        //     this.set_current_time_block_internal (session, time_block);
        // }



        // private unowned Pomodoro.Session? get_current_session ()
        // {
        //     return this._current_session;
        // }

        // /**
        //  * When timer is stopped `this._current_time_block` is set to null.
        //  *
        //  */
        // private unowned Pomodoro.TimeBlock? get_current_time_block ()
        // {
        //     if (this._current_time_block == null &&
        //         this.previous_time_block != null &&
        //         this.previous_time_block.session == this._current_session)
        //     {
        //         return this.previous_time_block;
        //     }
        //     else {
        //         return this._current_time_block;
        //     }
        // }

        // private unowned Pomodoro.TimeBlock? get_next_time_block ()
        // {
        //     return this._current_session != null
        //         ? this._current_session.get_next_time_block (this.get_current_time_block())
        //         : null;
        // }


        // private bool is_scheduled (Pomodoro.TimeBlock time_block)
        // {
        //     time_block

        //     index

        //     return
        // }

        private void reschedule (Pomodoro.Session session,
                                 int64            timestamp)
        {

        }


        private void mark_current_time_block_ended (int64 timestamp)
        {
            if (this._current_time_block != null && this._current_time_block.end_time > timestamp) {
                this._current_time_block.end_time = timestamp;
            }
        }

        private void mark_current_session_ended (int64 timestamp)
        {
            // TODO
            assert_not_reached ();
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
                var gap = new Pomodoro.Gap (time_block.end_time, timestamp);

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
            var session = time_block != null ? time_block.session : null;

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
                // var time_block_found = false;
                // var skipping = true;
                // Pomodoro.TimeBlock[] to_remove = {}

                // this.mark_current_time_block_ended ();

                // time_block.session.foreach_time_block ((_time_block) => {
                //     if (_time_block == this._current_time_block) {
                //         skipping = false;
                //         return;
                //     }

                //     if (skipping) {
                //         return;
                //     }

                //     if (_time_block == time_block) {
                //         time_block_found = true;
                //         skipping = true;
                //         return;
                //     }

                //     to_remove += _time_block;
                // });

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


            /*
                var time_block_link = session.time_blocks.find (time_block);
                var link            = time_block_link;
                var offset          = Pomodoro.Timestamp.subtract (timestamp, link.data.start_time);

                if (link != null) {
                    // link.data.start_time = timestamp
                    link = link.prev;

                    while (link != null) {
                        session.remove (link.data);

                        link = link.prev;
                    }
                }

                link = time_block_link;

                while (link != null) {
                    session.remove (link.data);

                    link = link.next;
                }


                // time_blocks.@foreach ((_time_block) => {
                //     _time_block.move_by (offset);
                //     time_block.session.append (_time_block);
                // });

                // var time_blocks = time_block.session.time_blocks.copy ();
                // tmp.remove_before (time_block);
                // time_block.session.move_to (timestamp);

                // var offset = this._current_time_block.end_time;

                // time_block.session.remove_after (this._current_time_block);

                // time_block.session.join (tmp);
                // time_blocks.@foreach ((_time_block) => {
                //     _time_block.move_by (offset);
                //     time_block.session.append (_time_block);
                // });
            }
            */
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
            // this.set_current_time_block_internal (next_session, next_time_block, timestamp);
        }

        public void advance (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var next_time_block = this._current_session != null
                ? this._current_session.get_next_time_block (this._current_time_block)
                : null;
            var next_session = next_time_block != null ? next_time_block.session : null;

            // var next_session    = this._current_session;
            // var next_time_block = next_session != null
            //     ? next_session.get_next_time_block (this.get_current_time_block ())
            //     : null;

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
            if (this.block_timer_signal_handlers_count > 0) {
                return;
            }

            // Nothing to resolve when state gets finished.
            // Advancing to a next time-block should be done after emitting `Timer.state_changed`.
            if (state.finished_time >= 0) {
                return;
            }

            // Stopping the timer.
            if (state.started_time < 0 && this._current_time_block == null) {
                state.user_data = null;
                return;
            }

            // Starting the timer. Initialize a new session or a time-block.
            if (state.started_time >= 0 && this._current_time_block == null) {
                var timestamp = state.started_time;

                this.advance_to_state (Pomodoro.State.POMODORO, state.started_time);

                state.started_time = timestamp;
                state.user_data = this._current_time_block;
                return;

                // state.duration = this._current_time_block.duration;  // TODO: Should not count gap times. At this point time-block should not have any gaps.
            }

            state.user_data = this._current_time_block;
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this.block_timer_signal_handlers_count > 0) {
                // TODO: emit leave_time_block and enter_time_block
                return;
            }

            var timestamp = this.timer.get_last_state_changed_time ();

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

        // TODO: is it used?
        // private void on_timer_state_changed_after (Pomodoro.TimerState current_state,
        //                                            Pomodoro.TimerState previous_state)
        // {
            // var has_pending_enter_session_signal = this.has_pending_enter_session_signal;
            // var has_pending_enter_time_block_signal = this.has_pending_enter_time_block_signal;
        //     var current_session = this._current_session;
        //     var current_time_block = this._current_time_block;

            // if (has_pending_enter_session_signal && current_session != null) {
            //     this.has_pending_enter_session_signal = false;
            //     this.enter_session (current_session);
            // }

            // if (has_pending_enter_time_block_signal && current_time_block != null && current_time_block == this._current_time_block) {
            //     this.has_pending_enter_time_block_signal = false;
            //     this.enter_time_block (current_time_block);
            // }
        // }

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
            // TODO: disconnect Timer signals

            base.dispose ();
        }
    }


    // ------------------------------------------------------------------------


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

        //     this._current_time_block.end_time = timestamp;
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



        // TODO: Move to set_current_time_block
        /*
        private void set_current_time_block_full (Pomodoro.Session?   session,
                                                  Pomodoro.TimeBlock? time_block)
        {
            var previous_session    = this._current_session;
            var previous_time_block = this._current_time_block;

            if (time_block == previous_time_block) {
                return;
            }

            if (previous_time_block != null) {
                this.leave_time_block (previous_time_block);
            }

            if (previous_session != null && session != previous_session) {
                this.leave_session (previous_session);
            }

            this.previous_session = this._current_session;
            this.previous_time_block = this._current_time_block;
            this._current_session = session;
            this._current_time_block = time_block;

            if (session != previous_session) {
                this.notify_property ("current-session");
            }

            this.notify_property ("current-time-block");

            if (session != null && session != previous_session) {
                this.has_pending_enter_session_signal = true;
            }

            if (time_block != null) {
                this.has_pending_enter_time_block_signal = true;

                this.timer.state = Pomodoro.TimerState () {
                    duration      = time_block.duration,
                    offset        = 0,
                    started_time  = Pomodoro.Timestamp.UNDEFINED,
                    paused_time   = Pomodoro.Timestamp.UNDEFINED,
                    finished_time = Pomodoro.Timestamp.UNDEFINED,
                    user_data     = time_block
                };
            }
            else {
                this.timer.reset ();
            }
        }
        */


}
