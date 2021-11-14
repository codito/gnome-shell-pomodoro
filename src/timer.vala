/*
 * Copyright (c) 2011-2015 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Arun Mahapatra <pratikarun@gmail.com>
 *          Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    private const double TIME_TO_RESET_SCORE = 3600.0;


    /**
     * Session (uninterrupted work including long breaks)
     * - set (4 pomodoros)
     *   - interval (individual pomodoros) / time block
     *
     *
     */




    /**
     * Pomodoro.Timer class.
     *
     * A class for a countdown timer. Timer works in an atomic manner, it acknowlegdes passage
     * of time after calling update() method.
     */
    public class Timer : GLib.Object
    {
        private static Pomodoro.Timer? instance = null;

        public TimerState state {
            get {
                return this._state;
            }
            set {
                this.set_state_full (value, value.timestamp);
            }
        }

        // deprecated, use state.duration
        [CCode (notify = false)]
        public double state_duration {
            get {
                return this._state != null ? this._state.duration : 0.0;
            }
            set {
                if (this._state != null) {
                    this._state.duration = value;
                }
            }
        }

        [CCode (notify = false)]
        public double elapsed {
            get {
                return this._state != null ? this._state.elapsed : 0.0;
            }
            set {
                this._state.elapsed = value;
                this.update_offset ();
            }
        }

        [CCode (notify = false)]
        public double remaining {
            get {
                return this._state != null ? this._state.duration - this._state.elapsed : 0.0;
            }
            set {
                this._state.elapsed = this._state.duration - value;
                this.update_offset ();
            }
        }

        [CCode (notify = false)]
        public double offset {
            get;
            private set;
        }

        [CCode (notify = false)]
        public bool is_paused {
            get {
                return this._is_paused;
            }
            set {
                this.set_is_paused_full (value, Pomodoro.get_current_time ());
            }
        }

        public double timestamp {
            get;
            construct set;
        }

        /**
         * Achieved score or number of completed pomodoros.
         *
         * It's updated on state change.
         */
        public double score {
            get; set; default = 0.0;
        }

        private uint timeout_source = 0;
        private Pomodoro.TimerState _state;
        private bool _is_paused;

        construct
        {
            this._state = new Pomodoro.DisabledState ();
            this.timestamp = this._state.timestamp;
        }

        public static unowned Pomodoro.Timer get_default ()
        {
            if (Timer.instance == null) {
                var timer = new Timer ();
                timer.set_default ();

                timer.destroy.connect_after (() => {
                    if (Timer.instance == timer) {
                        Timer.instance = null;
                    }
                });
            }

            return Timer.instance;
        }

        public void set_default ()
        {
            Timer.instance = this;
        }

        /**
         * Check whether timer is ticking.
         */
        public bool is_running ()
        {
            return this.timeout_source != 0;
            // return !(this.state is Pomodoro.DisabledState);
        }

        public void start (double timestamp = Pomodoro.get_current_time ())
        {
            this.resume (timestamp);

            if (this.state is Pomodoro.DisabledState) {
                this.state = new Pomodoro.PomodoroState.with_timestamp (timestamp);
            }
        }

        public void stop (double timestamp = Pomodoro.get_current_time ())
        {
            this.resume (timestamp);

            if (!(this.state is Pomodoro.DisabledState)) {
                this.state = new Pomodoro.DisabledState.with_timestamp (timestamp);
            }
        }

        public void toggle (double timestamp = Pomodoro.get_current_time ())
        {
            if (this.state is Pomodoro.DisabledState) {
                this.start (timestamp);
            }
            else {
                this.stop (timestamp);
            }
        }

        public void pause (double timestamp = Pomodoro.get_current_time ())
        {
            this.set_is_paused_full (true, timestamp);
        }

        public void resume (double timestamp = Pomodoro.get_current_time ())
        {
            this.set_is_paused_full (false, timestamp);
        }

        public void reset (double timestamp = Pomodoro.get_current_time ())
        {
            this.resume (timestamp);

            this.score = 0.0;
            this.state = new Pomodoro.DisabledState.with_timestamp (timestamp);
        }

        public void skip (double timestamp = Pomodoro.get_current_time ())
        {
            this.state = this._state.create_next_state (this.score, timestamp);
        }

        public void rewind (double seconds,
                            double timestamp = Pomodoro.get_current_time ())
        {
            // TODO: handle rewinding to previous state

            this._state.elapsed = double.max (this._state.elapsed - seconds, 0.0);
            this.update_offset ();
        }

        /**
         * set_state_full
         *
         * Changes the state and sets new timestamp
         */
        private void set_state_full (Pomodoro.TimerState state,
                                     double              timestamp)
        {
            var previous_state = this._state;

            this.timestamp = timestamp;

            this.state_leave (this._state);

            this._state = state;
            this.update_offset ();

            this.state_enter (this._state);

            if (!this.resolve_state ()) {
                this.state_changed (this._state, previous_state);
            }
        }

        private void set_is_paused_full (bool   value,
                                         double timestamp)
        {
            if (value && this.timeout_source == 0) {
                return;
            }

            if (value != this._is_paused) {
                this._is_paused = value;

                this.timestamp = timestamp;
                this.update_offset ();

                this.update_timeout ();

                this.notify_property ("is-paused");
            }
        }

        private bool on_timeout ()
        {
            this.update ();

            return true;
        }

        private void stop_timeout ()
        {
            if (this.timeout_source != 0) {
                GLib.Source.remove (this.timeout_source);
                this.timeout_source = 0;
            }
        }

        private void start_timeout ()
        {
            if (this.timeout_source == 0) {
                this.timeout_source = GLib.Timeout.add (1000, this.on_timeout);
            }
        }

        private void update_timeout ()
        {
            if (this.state is DisabledState || this._is_paused) {
                this.stop_timeout ();
            }
            else {
                this.start_timeout ();
            }
        }

        private void update_offset ()
        {
            this._offset = (this.timestamp - this._state.timestamp) - this._state.elapsed;
        }

        private void update_elapsed ()
        {
            this._state.elapsed = this.timestamp - this._state.timestamp - this._offset;
        }

        /**
         * Resolve next states after timer elapse or state change.
         *
         * Return true if state has been changed.
         */
        private bool resolve_state ()
        {
            var original_state = this._state as Pomodoro.TimerState;
            var state_changed = false;

            while (this._state.duration > 0.0 &&
                   this._state.is_completed ())
            {
                this.state_leave (this._state);

                this._state = this._state.create_next_state (this.score, this.timestamp);
                this.update_offset ();

                state_changed = true;

                this.state_enter (this._state);
            }

            if (state_changed) {
                this.state_changed (this._state, original_state);
            }

            return state_changed;
        }

        // public int64 calculate_elapsed (int64 timestamp)  // TODO: rename to get_elapsed once property is removed
        // {
        //     return timestamp - (int64)(this._state.timestamp * 1000.0) - (int64)(this._offset * 1000.0);
        // }

        // public double calculate_state_progress (int64 timestamp)  // TODO: move it to State class
        // {
        //     if (this.state_duration <= 0.0) {
        //         return 0.0;
        //     }

        //     warning ( "### %.6f %.6f", ((double) timestamp) / USEC_PER_SEC, this._state.timestamp);

        //     return (
        //         ((double) timestamp) / USEC_PER_SEC - this._state.timestamp - this._offset
        //     ) / this.state_duration;
        // }

        // public double calculate_elapsed_double (int64 timestamp)  // TODO: rename to get_elapsed once property is removed
        // {
        //     return ((double) this.calculate_elapsed_double (timestamp)) / 1000.0;
        // }

        public virtual signal void update (double timestamp = Pomodoro.get_current_time ())
        {
            this.timestamp = timestamp;

            if (!this._is_paused)
            {
                this.update_elapsed ();

                if (!this.resolve_state ()) {
                    this.notify_property ("elapsed");
                }
            }
            else {
                this.update_offset ();
            }
        }

        public virtual signal void state_enter (TimerState state)
        {
            state.notify["duration"].connect (this.on_state_duration_notify);
        }

        public virtual signal void state_leave (TimerState state)
        {
            state.notify["duration"].disconnect (this.on_state_duration_notify);

            this.score = state.calculate_score (this.score, this.timestamp);
        }

        public virtual signal void state_changed (TimerState state,
                                                  TimerState previous_state)
        {
            Pomodoro.sync_monotonic_time ();

            /* Run the timer */
            this.update_timeout ();

            this.notify_property ("state");  // TODO: is it needed?
            this.notify_property ("elapsed");
        }

        private void on_state_duration_notify ()
        {
            this.update (this.timestamp);

            this.notify_property ("state-duration");
        }

        public GLib.ActionGroup get_action_group ()
        {
            return Pomodoro.TimerActionGroup.for_timer (this);
        }

        /**
         * Saves timer state to settings.
         */
        public void save (GLib.Settings settings)
                          requires (settings.settings_schema.get_id () == "org.gnomepomodoro.Pomodoro.state")
        {
            var timer_datetime = new DateTime.from_unix_utc (
                                 (int64) Math.floor (this.timestamp));

            var state_datetime = new DateTime.from_unix_utc (
                                 (int64) Math.floor (this.state.timestamp));

            settings.set_string ("timer-state",
                                 this.state.name);
            settings.set_double ("timer-state-duration",
                                 this.state.duration);
            settings.set_string ("timer-state-date",
                                 state_datetime.to_string ());
            settings.set_double ("timer-elapsed",
                                 this.state.elapsed);
            settings.set_double ("timer-score",
                                 this.score);
            settings.set_string ("timer-date",
                                 timer_datetime.to_string ());
            settings.set_boolean ("timer-paused",
                                  this.is_paused);
        }

        /**
         * Restores timer state from settings.
         *
         * When restoring, lost time is considered as interruption.
         * If exceeded time of a long break, timer would reset.
         */
        public void restore (GLib.Settings settings,
                             double        timestamp = Pomodoro.get_current_time ())
                             requires (settings.settings_schema.get_id () == "org.gnomepomodoro.Pomodoro.state")
        {
            var state          = Pomodoro.TimerState.lookup (settings.get_string ("timer-state"));
            var is_paused      = settings.get_boolean ("timer-paused");
            var score          = settings.get_double ("timer-score");
            var last_timestamp = 0.0;

            if (state != null)
            {
                state.duration = settings.get_double ("timer-state-duration");
                state.elapsed  = settings.get_double ("timer-elapsed");

                var state_datetime = new DateTime.from_iso8601 (
                                   settings.get_string ("timer-state-date"), new TimeZone.local ());

                var last_datetime = new DateTime.from_iso8601 (
                                   settings.get_string ("timer-date"), new TimeZone.local ());

                if (state_datetime != null && last_datetime != null) {
                    state.timestamp = (double) state_datetime.to_unix ();
                    last_timestamp = (double) last_datetime.to_unix ();
                }
                else {
                    /* In case there is no valid state-date, elapsed time
                     * will be lost.
                     */
                    state = null;
                }
            }

            if (state != null && timestamp - last_timestamp < TIME_TO_RESET_SCORE)
            {
                this.freeze_notify ();
                this.score = score;
                this.set_state_full (state, last_timestamp);
                this.pause (last_timestamp);
                this.thaw_notify ();

                this.update (timestamp);

                if (is_paused) {
                    this.notify_property ("is-paused");
                }
                else {
                    this.resume (timestamp);
                }
            }
            else {
                this.reset (timestamp);
            }
        }

        public virtual signal void destroy ()
        {
            this.dispose ();
        }

        public override void dispose ()
        {
            if (this.timeout_source != 0) {
                GLib.Source.remove (this.timeout_source);
                this.timeout_source = 0;
            }

            base.dispose ();
        }
    }
}
