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
     * Helper structure for keeping several fields at once. Together they can be vewed as a state.
     */
    [Immutable]
    public struct TimerState
    {
        public int64 duration;
        public int64 offset;
        public int64 start_timestamp;
        public int64 stop_timestamp;
        public int64 change_timestamp;
        public bool  is_finished;
        public void* user_data;

        public Pomodoro.TimerState copy ()
        {
            return Pomodoro.TimerState () {
                duration = this.duration,
                offset = this.offset,
                start_timestamp = this.start_timestamp,
                stop_timestamp = this.stop_timestamp,
                change_timestamp = this.change_timestamp,
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
            builder.add ("{sv}", "start_timestamp", new GLib.Variant.int64 (this.start_timestamp));
            builder.add ("{sv}", "stop_timestamp", new GLib.Variant.int64 (this.stop_timestamp));
            builder.add ("{sv}", "change_timestamp", new GLib.Variant.int64 (this.change_timestamp));
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
        private const int64 MIN_TIMEOUT = 125000;  // 0.125s
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

                if (this._state.change_timestamp < 0) {
                    this._state.change_timestamp = Pomodoro.Timestamp.from_now ();
                    // TODO: does it propagate to value?
                }

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
                new_state.is_finished = false;
                new_state.change_timestamp = Pomodoro.Timestamp.from_now ();

                this.state = new_state;

                // TODO: do we need to recalculate offset?
            }
        }

        /**
         * Time when timer has been initialized/started.
         */
        public int64 timestamp {
            get {
                return this._state.start_timestamp != Pomodoro.Timestamp.UNDEFINED
                    ? this._state.start_timestamp
                    : this._state.stop_timestamp;
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
                new_state.change_timestamp = Pomodoro.Timestamp.from_now ();

                this.state = new_state;
            }
        }

        private uint  timeout_id = 0;
        private int64 timeout_remaining = 0;  // TODO: replace with SynchronizationInfo structure?
        private Pomodoro.TimerState _state;

        //  = Pomodoro.TimerState () {
        //     duration = 0,
        //     offset = 0,
        //     start_timestamp = Pomodoro.Timestamp.UNDEFINED,
        //     stop_timestamp = 0,
        //     change_timestamp = 0,
        //     is_finished = false,
        //     user_data = null
        // };

        public Timer (int64 duration = 0,
                      void* user_data = null)
                      requires (duration >= 0)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();

            this._state = Pomodoro.TimerState () {
                duration = duration,
                offset = 0,
                start_timestamp = Pomodoro.Timestamp.UNDEFINED,
                stop_timestamp = timestamp,
                change_timestamp = timestamp,
                is_finished = false,
                user_data = user_data
            };
        }

        public Timer.with_state (Pomodoro.TimerState state)
        {
            this._state = state;
            this.update_timeout ();
        }

        ~Timer ()
        {
            if (Pomodoro.Timer.instance == null) {
                Pomodoro.Timer.instance = null;
            }
        }

        /**
         * Return a defualt timer.
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
            return this._state.start_timestamp >= 0;  // && this._state.stop_timestamp < 0;
        }

        public bool is_stopped ()
        {
            return this._state.stop_timestamp >= 0;
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
                start_timestamp = Pomodoro.Timestamp.UNDEFINED,
                stop_timestamp = timestamp,
                change_timestamp = timestamp,
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

            if (new_state.start_timestamp < 0) {
                // start for first time
                new_state.start_timestamp = timestamp;
            }
            else if (new_state.stop_timestamp >= 0) {
                // continue already stopped timer
                new_state.offset += timestamp - new_state.stop_timestamp;
            }

            new_state.stop_timestamp = Pomodoro.Timestamp.UNDEFINED;
            new_state.change_timestamp = timestamp;

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
            new_state.stop_timestamp = timestamp;
            new_state.change_timestamp = timestamp;

            this.state = new_state;
        }


        // TODO: remove, it's equivalent to .finish()
        /**
         * Jump to end, so that state is counted as finished.
         *
         * Call is ignored when the timer is finished.
         */
        public void skip (int64 timestamp = -1)
        {
            this.finish (timestamp);

            // if (this.is_finished ()) {
            //     return;
            // }

            // if (!this.is_started ()) {
            //     return;
            // }

            // Pomodoro.ensure_timestamp (ref timestamp);

            // this.stop_timeout ();
            // this.change (
            //     Pomodoro.TimerState () {
            //         duration = this.state.duration,
            //         offset = this.state.offset,
            //         start_timestamp = this.state.start_timestamp,
            //         stop_timestamp = timestamp,
            //         change_timestamp = timestamp,
            //         is_finished = true
            //     }
            // );

            // Normally "finished" signal is emited after reaching timeout.
            // It's triggered manually.
            // this.finished (this.state);
        }

        /**
         * Rewind the timer or undo it if you pass negative value.
         *
         * Call is ignored when the timer is finished.
         */
        public void rewind (int64 microseconds,
                            int64 timestamp = -1)
        {
            // TODO: warn if rewinding with negative value

            // if (this.is_finished () || this.is_stopped ()) {
            //     return;
            // }

            if (!this.is_started ()) {
                return;
            }

            // return_if_fail (this.is_started ());

            Pomodoro.ensure_timestamp (ref timestamp);

            this.change (
                Pomodoro.TimerState () {
                    duration = this.state.duration,
                    offset = int64.max (this.state.offset - microseconds, 0),
                    start_timestamp = this.state.start_timestamp,
                    stop_timestamp = timestamp,
                    change_timestamp = timestamp,
                    is_finished = false
                }
            );

            // TODO: handle rewinding to previous state?
        }

        /**
         * Extend the duration. `duration` can be negative, which is synonymous with undoing the action.
         */
        public void extend (int64 microseconds,
                            int64 timestamp = -1)
        {
            // if (this.is_finished ()) {  // TODO: resume timer
            // }

            Pomodoro.ensure_timestamp (ref timestamp);

            // TODO: it should work differently when running

            // TODO: check if we're truly extending the duration

            this.change (
                Pomodoro.TimerState () {
                    duration = int64.max (this.state.duration + microseconds, 0),
                    offset = this.state.offset,
                    start_timestamp = this.state.start_timestamp,
                    stop_timestamp = this.state.stop_timestamp,
                    change_timestamp = timestamp,
                    is_finished = false
                }
            );

            // TODO: handle rewinding to previous state
            // var offset_reference = this.internal_state.duration + this.internal_state.offset;

            // TODO: push new internal_state
            // this.internal_state.offset = int64.max (offset_reference - duration, 0) - offset_reference;
        }

        private void finish (int64 timestamp = -1)
        {
            this.stop_timeout ();

            if (this.is_finished ()) {
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.change_timestamp = timestamp;
            new_state.is_finished = true;

            if (new_state.start_timestamp < 0) {
                new_state.start_timestamp = timestamp;
            }

            if (new_state.stop_timestamp < 0) {
                new_state.stop_timestamp = timestamp;
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
                ? this.timeout_remaining - 1000000  // 1s, as scheduled using `GLib.Timeout.add_seconds()`
                : remaining;

            if ((remaining - this.timeout_remaining).abs () > 1000000) {  // 1s
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

        private void update_timeout ()
        {
            if (!this._state.is_finished
                && this._state.start_timestamp >= 0
                && this._state.stop_timestamp < 0)
            {
                this.start_timeout (this._state.change_timestamp);
            }
            else {
                this.stop_timeout ();
            }
        }


        public int64 calculate_elapsed (int64 timestamp = -1)
        {
            if (this._state.start_timestamp < 0) {
                return 0;
            }

            if (this._state.stop_timestamp >= 0) {
                timestamp = this._state.stop_timestamp;
            }
            else {
                Pomodoro.ensure_timestamp (ref timestamp);
            }

            return (
                timestamp - this._state.start_timestamp - this._state.offset
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

        // TODO: remove from here
        // public GLib.ActionGroup get_action_group ()
        // {
        //     return Pomodoro.TimerActionGroup.for_timer (this);
        // }

        /**
         * Emitted on any state related changes. Default handler acknowledges the change.
         */
        public signal void state_changed (Pomodoro.TimerState current_state,
                                          Pomodoro.TimerState previous_state)
        {
            assert (current_state == this._state);

            this.update_timeout ();

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
         * Emitted when countdown reaches zero, current state should be treated as finished
         * when `.skip()` was called.
         */
        public signal void finished (Pomodoro.TimerState state);

        public override void dispose ()
        {
            this.stop_timeout ();

            base.dispose ();
        }


        // TODO: remove these

        // use Timer.state directly
        private void change (Pomodoro.TimerState new_state)
        {
            this.state = new_state;
        }

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
    }
}
