/*
 * Copyright (c) 2022 gnome-pomodoro contributors
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
    /**
     * Helper structure for changing several fields at once. Together they can be regarded as a timer state.
     */
    [Immutable]
    public struct TimerState
    {
        public int64 duration;
        public int64 offset;
        public int64 started_time;
        public int64 stopped_time;
        public bool  is_finished;
        public void* user_data;

        public Pomodoro.TimerState copy ()
        {
            return Pomodoro.TimerState () {
                duration = this.duration,
                offset = this.offset,
                started_time = this.started_time,
                stopped_time = this.stopped_time,
                is_finished = this.is_finished,
                user_data = this.user_data
            };
        }

        /**
         * Convert structure to Variant.
         *
         * Used in tests.
         */
        public GLib.Variant to_variant ()
        {
            var builder = new GLib.VariantBuilder (new GLib.VariantType ("a{s*}"));
            builder.add ("{sv}", "duration", new GLib.Variant.int64 (this.duration));
            builder.add ("{sv}", "offset", new GLib.Variant.int64 (this.offset));
            builder.add ("{sv}", "started_time", new GLib.Variant.int64 (this.started_time));
            builder.add ("{sv}", "stopped_time", new GLib.Variant.int64 (this.stopped_time));
            builder.add ("{sv}", "is_finished", new GLib.Variant.boolean (this.is_finished));
            // builder.add ("{smh}", "user_data", this.user_data);

            return builder.end ();
        }
    }


    /**
     * Timer class mimicks a physical countdown timer.
     *
     * It trigger events on state changes. To triger ticking event at regular intervals use TimerTicker.
     */
    public class Timer : GLib.Object
    {
        /**
         * Time that is within tolerance not to schedule a timeout.
         */
        private const int64 MIN_TIMEOUT = 125000;  // 0.125s

        /**
         * Remaining time at which we no longer can rely on an idle timeout, and a higher precision timeout
         * should be scheduled.
         */
        private const int64 MIN_IDLE_TIMEOUT = 1500000;  // 1.5s

        private static unowned Pomodoro.Timer? instance = null;

        /**
         * Timer internal state.
         *
         * You should not change its fields directly.
         */
        public Pomodoro.TimerState state {
            get {
                return this._state;
            }
            set {
                // TODO: validate state

                var previous_state = this._state;

                this._state = value;

                // TODO: notify properties?

                this.state_changed (this._state, previous_state);
            }
        }

        /**
         * The intended duration of the state, or running time of the timer.
         */
        public int64 duration {
            get {
                return this._state.duration;
            }
            construct set {
                if (value == this._state.duration) {
                    return;
                }

                if (value < 0) {
                    // TODO: log warning
                    value = 0;
                }

                var new_state = this._state.copy ();
                new_state.duration = value;

                if (new_state.duration > this._state.duration) {
                    new_state.is_finished = false;
                }

                this.state = new_state;
            }
        }

        /**
         * Time when timer has been initialized/started.
         */
        public int64 timestamp {
            get {
                return this._state.started_time != Pomodoro.Timestamp.UNDEFINED
                    ? this._state.started_time
                    : this._state.stopped_time;
            }
        }

        /**
         * Time lost during previous pauses. If pause is ongoing its not counted here yet.
         */
        public int64 offset {
            get {
                return this._state.offset;
            }
        }

        /**
         * Extra data associated with current state
         */
        public void* user_data {
            get {
                return this._state.user_data;
            }
            construct set {
                // TODO warn if changing a finished state

                var new_state = this.state.copy ();
                new_state.user_data = value;

                this.state = new_state;
            }
        }

        private uint  timeout_id = 0;
        private int64 timeout_remaining = 0;  // TODO: replace with SynchronizationInfo structure?
        private int64 last_state_changed_time = Pomodoro.Timestamp.UNDEFINED;
        private Pomodoro.TimerState _state;


        public Timer (int64 duration = 0,
                      void* user_data = null)
                      requires (duration >= 0)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();

            this._state = Pomodoro.TimerState () {
                duration = duration,
                offset = 0,
                started_time = Pomodoro.Timestamp.UNDEFINED,
                stopped_time = timestamp,
                is_finished = false,
                user_data = user_data
            };
        }

        public Timer.with_state (Pomodoro.TimerState state)
        {
            this._state = state;
            this.last_state_changed_time = Pomodoro.Timestamp.from_now ();

            this.update_timeout (this.last_state_changed_time);
        }

        ~Timer ()
        {
            if (Pomodoro.Timer.instance == null) {
                Pomodoro.Timer.instance = null;
            }
        }

        /**
         * Return a default timer or `null` if none is set.
         */
        public static unowned Pomodoro.Timer? get_default ()
        {
            return Pomodoro.Timer.instance;
        }

        public void set_default ()
        {
            Pomodoro.Timer.instance = this;
        }

        public bool is_default ()
        {
            return Pomodoro.Timer.instance == this;
        }

        /**
         * Return whether timer is ticking -- whether timer has started and is not paused.
         */
        public bool is_running ()
        {
            return this.timeout_id != 0;
        }

        /**
         * Return whether timer has been started. Returns true also when stopped or finished.
         */
        public bool is_started ()
        {
            return this._state.started_time >= 0;
        }

        public bool is_stopped ()
        {
            return this._state.stopped_time >= 0;
        }

        public bool is_finished ()
        {
            return this._state.is_finished;
        }

        /**
         * Reset timer to initial state.
         */
        public void reset (int64 duration = 0,
                           void* user_data = null,
                           int64 timestamp = -1)
                           requires (duration >= 0)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.state = Pomodoro.TimerState () {
                duration = duration,
                offset = 0,
                started_time = Pomodoro.Timestamp.UNDEFINED,
                stopped_time = timestamp,
                is_finished = false,
                user_data = user_data
            };
        }

        /**
         * Start the timer or continue where it left off.
         */
        public void start (int64 timestamp = -1)
        {
            if (this.is_finished ()) {
                return;
            }

            if (this.is_started () && !this.is_stopped ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();

            if (new_state.started_time < 0) {
                // start for first time
                new_state.started_time = timestamp;
            }
            else if (new_state.stopped_time >= 0) {
                // continue already stopped timer
                new_state.offset += timestamp - new_state.stopped_time;
            }

            new_state.stopped_time = Pomodoro.Timestamp.UNDEFINED;

            this.state = new_state;
        }

        /**
         * Stop the timer if it's running.
         */
        public void stop (int64 timestamp = -1)
        {
            if (this.is_finished () || this.is_stopped ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.stopped_time = timestamp;

            this.state = new_state;
        }

        /**
         * Rewind the timer or undo it if you pass negative value.
         *
         * Call is ignored when the timer is finished.
         */
        public void rewind (int64 microseconds,
                            int64 timestamp = -1)
        {
            if (!this.is_started ()) {
                return;
            }

            if (microseconds == 0) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            if (new_state.stopped_time >= 0 && new_state.started_time >= 0) {
                new_state.stopped_time = int64.max (new_state.stopped_time - microseconds, new_state.started_time);
            }

            if (microseconds > 0) {
                new_state.is_finished = false;
            }

            // TODO
            new_state.offset = int64.max (this._state.offset - microseconds, 0);

            this.state = new_state;

            // TODO: timer itself won't handle rewinding to a previous state
        }

        private void finish (int64 timestamp = -1)
        {
            this.stop_timeout ();

            if (this.is_finished ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.is_finished = true;

            if (new_state.started_time < 0) {
                new_state.started_time = timestamp;
            }

            if (new_state.stopped_time < 0) {
                new_state.stopped_time = timestamp;
            }
            else {
                // TODO: calculate offset
            }

            this.state = new_state;
        }

        /**
         * Idle timeout.
         *
         * Serves as a heartbeat. Checks whether there are delays or whether system has been suspended.
         */
        private bool on_timeout_idle ()
                                      requires (this.timeout_id != 0)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var remaining = this.calculate_remaining (timestamp);

            // Check if already finished
            if (remaining <= MIN_TIMEOUT) {
                this.stop_timeout ();
                this.finish (timestamp);

                return GLib.Source.REMOVE;
            }

            // Emit synchronize signal if needed
            this.timeout_remaining = this.timeout_remaining > 0
                ? this.timeout_remaining - Pomodoro.Interval.SECOND
                : remaining;

            if ((remaining - this.timeout_remaining).abs () > Pomodoro.Interval.SECOND) {
                this.timeout_remaining = remaining;
                this.synchronize (
                    // timestamp,
                    // this.calculate_elapsed (timestamp),
                    // this.is_running ()
                );
            }

            // Check whether to switch to a more precise timeout
            if (remaining <= MIN_IDLE_TIMEOUT) {
                this.stop_timeout ();
                this.do_start_timeout (remaining, timestamp);

                return GLib.Source.REMOVE;
            }

            return GLib.Source.CONTINUE;
        }

        /**
         * Precise timeout.
         *
         * It's meant to be fired once at the ond of current time-block.
         */
        private bool on_timeout ()
                                 requires (this.timeout_id != 0)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var remaining = this.calculate_remaining (timestamp);

            this.stop_timeout ();

            if (remaining > MIN_TIMEOUT) {
                this.do_start_timeout (remaining, timestamp);
            }
            else {
                this.finish (timestamp);
            }

            return GLib.Source.REMOVE;
        }

        private void do_start_timeout (int64 remaining,
                                       int64 timestamp)
        {
            if (remaining > MIN_IDLE_TIMEOUT) {
                this.timeout_id = GLib.Timeout.add_seconds_full (GLib.Priority.DEFAULT_IDLE, 1, this.on_timeout_idle);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout_idle");
            }
            else if (remaining > MIN_TIMEOUT) {
                this.timeout_id = GLib.Timeout.add_full (GLib.Priority.DEFAULT, (uint) (remaining / 1000), this.on_timeout);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout");
            }
            else {
                this.finish (timestamp);
            }
        }

        private void start_timeout (int64 timestamp = -1)
        {
            if (this.timeout_id != 0 ) {
                return;  // already running
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            this.do_start_timeout (this.calculate_remaining (timestamp),
                                   timestamp);
        }

        private void stop_timeout ()
        {
            if (this.timeout_id == 0) {
                return;
            }

            GLib.Source.remove (this.timeout_id);
            this.timeout_id = 0;
            this.timeout_remaining = 0;
        }

        private void update_timeout (int64 timestamp = -1)
        {
            if (!this._state.is_finished
                && this._state.started_time >= 0
                && this._state.stopped_time < 0)
            {
                this.start_timeout (timestamp);
            }
            else {
                this.stop_timeout ();
            }
        }

        /**
         * Calculate elapsed time
         *
         * In an unlikely case when `timestamp < stopped_time` the result will be estimated.
         */
        public int64 calculate_elapsed (int64 timestamp = -1)
        {
            if (this._state.started_time < 0) {
                return 0;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            if (this._state.stopped_time >= 0) {
                timestamp = int64.min (this._state.stopped_time, timestamp);
            }

            return (
                timestamp - this._state.started_time - this._state.offset
            ).clamp (0, this._state.duration);
        }

        public int64 calculate_remaining (int64 timestamp = -1)
        {
            return this._state.duration - this.calculate_elapsed (timestamp);
        }

        public double calculate_progress (int64 timestamp = -1)
        {
            var elapsed = (double) this.calculate_elapsed (timestamp);
            var duration = (double) this._state.duration;

            return duration > 0.0 ? elapsed / duration : 0.0;
        }

        /**
         * Emitted on any state related changes. Default handler acknowledges the change.
         */
        public signal void state_changed (Pomodoro.TimerState current_state,
                                          Pomodoro.TimerState previous_state)
        {
            assert (current_state == this._state);

            if (current_state.started_time > 0 && current_state.started_time > this.last_state_changed_time) {
                this.last_state_changed_time = current_state.started_time;
            }

            if (current_state.stopped_time > 0 && current_state.stopped_time > this.last_state_changed_time) {
                this.last_state_changed_time = current_state.stopped_time;
            }

            this.update_timeout (this.last_state_changed_time);

            if (current_state.is_finished && !previous_state.is_finished) {
                this.finished (current_state);
            }
        }

        /**
         * It should be safe to increment elapsed time in `GLib.Timeout.add_seconds` callback.
         * Just in case Timer tracks those any deviations and advises tickers to synchronize.
         */
        public signal void synchronize (
            // int64 timestamp,
            // int64 elapsed,
            // bool  is_running
        );

        /**
         * Emitted when countdown is close to zero or passed it.
         */
        public signal void finished (Pomodoro.TimerState state);

        public override void dispose ()
        {
            this.stop_timeout ();

            base.dispose ();
        }


        // --------------------------------------------------------------------------

        // TODO: remove these

        // use Timer.state directly
        // private void change (Pomodoro.TimerState new_state)
        // {
        //     this.state = new_state;
        // }


        // TODO: remove, it's equivalent to .finish()
        // /**
        //  * Jump to end, so that state is counted as finished.
        //  *
        //  * Call is ignored when the timer is finished.
        //  */
        // public void skip (int64 timestamp = -1)
        // {
        //     this.finish (timestamp);

            // if (this.is_finished ()) {
            //     return;
            // }

            // if (!this.is_started ()) {
            //     return;
            // }

            // Pomodoro.ensure_timestamp (ref timestamp);

            // this.stop_timeout ();
            // this.state = Pomodoro.TimerState () {
            //     duration = this.state.duration,
            //     offset = this.state.offset,
            //     started_time = this.state.started_time,
            //     stopped_time = timestamp,
            //     is_finished = true
            // };

            // Normally "finished" signal is emited after reaching timeout.
            // It's triggered manually.
            // this.finished (this.state);
        // }

        // /**
        //  * Extend the duration. `duration` can be negative, which is synonymous with undoing the action.
        //  */
        // public void extend (int64 microseconds,
        //                     int64 timestamp = -1)
        // {
            // if (this.is_finished ()) {  // TODO: resume timer
            // }

        //     Pomodoro.ensure_timestamp (ref timestamp);

            // TODO: it should work differently when running

            // TODO: check if we're truly extending the duration

        //     this.state = Pomodoro.TimerState () {
        //         duration = int64.max (this.state.duration + microseconds, 0),
        //         offset = this.state.offset,
        //         started_time = this.state.started_time,
        //         stopped_time = this.state.stopped_time,
        //         is_finished = false
        //     };

            // TODO: handle rewinding to previous state
            // var offset_reference = this.internal_state.duration + this.internal_state.offset;

            // TODO: push new internal_state
            // this.internal_state.offset = int64.max (offset_reference - duration, 0) - offset_reference;
        // }

        public bool is_paused ()
        {
            return false;
        }

        public void pause (int64 timestamp = -1)
        {
        }

        public void resume (int64 timestamp = -1)
        {
        }

        public void skip (int64 timestamp = -1)
        {
        }
    }
}
