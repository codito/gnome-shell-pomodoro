/*
 * Copyright (c) 2022-2023 gnome-pomodoro contributors
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
     *
     * `user_data` in our use refers to a time block, but don't over use it.
     */
    [Immutable]
    public struct TimerState
    {
        public int64 duration;
        public int64 offset;
        public int64 started_time;
        public int64 paused_time;
        public int64 finished_time;
        public void* user_data;

        public TimerState ()
        {
            this.duration = 0;
            this.offset = 0;
            this.started_time = Pomodoro.Timestamp.UNDEFINED;
            this.paused_time = Pomodoro.Timestamp.UNDEFINED;
            this.finished_time = Pomodoro.Timestamp.UNDEFINED;
            this.user_data = null;
        }

        /**
         * Make state copy
         *
         * This function is unnecessary. Structs in vala are copied by default. It's kept
         * to bring more clarity to our code.
         */
        public Pomodoro.TimerState copy ()
        {
            return this;
        }

        public bool equals (Pomodoro.TimerState other)
        {
            return this.duration == other.duration &&
                   this.offset == other.offset &&
                   this.started_time == other.started_time &&
                   this.paused_time == other.paused_time &&
                   this.finished_time == other.finished_time &&
                   this.user_data == other.user_data;
        }

        public bool is_valid ()
        {
            // Negative duration.
            if (this.duration < 0) {
                return false;
            }

            // Finished, but not started.
            if (Pomodoro.Timestamp.is_defined (this.finished_time) &&
                Pomodoro.Timestamp.is_undefined (this.started_time))
            {
                return false;
            }

            // Finished and still paused.
            if (Pomodoro.Timestamp.is_defined (this.finished_time) &&
                Pomodoro.Timestamp.is_defined (this.paused_time))
            {
                return false;
            }

            // Paused before started.
            if (Pomodoro.Timestamp.is_defined (this.paused_time) && this.paused_time < this.started_time) {
                return false;
            }

            // Finished before started.
            if (Pomodoro.Timestamp.is_defined (this.finished_time) && this.finished_time < this.started_time) {
                return false;
            }

            return true;
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
            builder.add ("{sv}", "paused_time", new GLib.Variant.int64 (this.paused_time));
            builder.add ("{sv}", "finished_time", new GLib.Variant.int64 (this.finished_time));
            // builder.add ("{smh}", "user_data", this.user_data);

            return builder.end ();
        }

        /**
         * Represent state as string.
         *
         * Used in tests.
         */
        public string to_representation ()
        {
            var representation = new GLib.StringBuilder ("TimerState (\n");
            representation.append (@"    duration = $duration,\n");
            representation.append (@"    offset = $offset,\n");
            representation.append (@"    started_time = $started_time,\n");
            representation.append (@"    paused_time = $paused_time,\n");
            representation.append (@"    finished_time = $finished_time,\n");
            representation.append (this.user_data == null
                ? "    user_data = null\n"
                : "    user_data = not null\n");
            representation.append (")");

            return representation.str;
        }
    }


    /**
     * Timer class mimics a physical countdown timer.
     *
     * It trigger events on state changes. To trigger ticking event at regular intervals use TimerTicker.
     */
    public class Timer : GLib.Object
    {
        /**
         * Interval of the ticking signal.
         */
        private const int64 TICKING_INTERVAL = Pomodoro.Interval.SECOND;

        /**
         * Time that is within tolerance not to schedule a timeout.
         */
        private const int64 TICKING_TOLERANCE = 20 * Pomodoro.Interval.MILLISECOND;

        private static Pomodoro.Timer? instance = null;

        /**
         * Timer internal state.
         *
         * You should not change its fields directly.
         */
        [CCode(notify = false)]
        public Pomodoro.TimerState state {
            get {
                return this._state;
            }
            set {
                this.set_state_full (value);
            }
        }

        /**
         * The intended duration of the state, not counting gaps/interruptions.
         */
        [CCode(notify = false)]
        public int64 duration {
            get {
                return this._state.duration;
            }
            set {
                if (value < 0) {
                    GLib.debug ("Trying to set a negative timer duration (%.1fs).",
                                Pomodoro.Timestamp.to_seconds (value));
                    value = 0;
                }

                if (value == this._state.duration) {
                    return;
                }

                var new_state = this._state.copy ();
                new_state.duration = value;

                if (new_state.duration > this._state.duration) {
                    new_state.finished_time = Pomodoro.Timestamp.UNDEFINED;
                }

                this.state = new_state;
            }
        }

        /**
         * Time when timer has been initialized/started.
         */
        [CCode(notify = false)]
        public int64 started_time {
            get {
                return this._state.started_time;
            }
        }

        /**
         * Time lost during previous pauses. If pause is ongoing its not counted here yet.
         */
        [CCode(notify = false)]
        public int64 offset {
            get {
                return this._state.offset;
            }
        }

        /**
         * Extra data associated with current state
         */
        [CCode(notify = false)]
        public void* user_data {
            get {
                return this._state.user_data;
            }
            set {
                if (value == this._state.user_data) {
                    return;
                }

                if (this.is_finished ()) {
                    GLib.debug ("Trying to set timer user-data after it finished");
                }

                var new_state = this._state.copy ();
                new_state.user_data = value;

                this.state = new_state;
            }
        }

        private Pomodoro.TimerState   _state = Pomodoro.TimerState ();
        private uint                  timeout_id = 0;
        private int64                 last_state_changed_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                 last_tick_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                 suspend_time = Pomodoro.Timestamp.UNDEFINED;
        private bool                  resolving_state = false;
        private Pomodoro.TimerState?  state_to_resolve = null;
        private int                   tick_freeze_count = 0;
        private int64                 monotonic_time_offset = 0;
        private Pomodoro.SleepMonitor sleep_monitor;
        private ulong                 prepare_for_sleep_id = 0;
        private ulong                 woke_up_id = 0;


        construct
        {
            this.sleep_monitor = Pomodoro.SleepMonitor.get_default ();
            this.prepare_for_sleep_id = this.sleep_monitor.prepare_for_sleep.connect (
                () => {
                    if (this.is_running ()) {
                        this.suspend_time = this.get_current_time ();
                        this.stop_timeout (this.suspend_time);
                    }
                }
            );
            this.woke_up_id = this.sleep_monitor.woke_up.connect (
                () => {
                    if (this.is_running ()) {
                        var timestamp = Pomodoro.Timestamp.from_now ();

                        this.synchronize (Pomodoro.Timestamp.UNDEFINED, timestamp);
                        this.suspended (this.suspend_time, timestamp);
                    }

                    this.suspend_time = Pomodoro.Timestamp.UNDEFINED;
                }
            );
        }

        public Timer (int64 duration = 0,
                      void* user_data = null)
                      requires (duration >= 0)
        {
            this._state = Pomodoro.TimerState () {
                duration = duration,
                offset = 0,
                started_time = Pomodoro.Timestamp.UNDEFINED,
                paused_time = Pomodoro.Timestamp.UNDEFINED,
                finished_time = Pomodoro.Timestamp.UNDEFINED,
                user_data = user_data
            };
        }

        public Timer.with_state (Pomodoro.TimerState state)
        {
            this._state = state;

            if (Pomodoro.Timestamp.is_defined (this._state.started_time)) {
                this.last_state_changed_time = Pomodoro.Timestamp.from_now ();
                this.start_timeout (this.last_state_changed_time);
            }
        }

        ~Timer ()
        {
            if (Pomodoro.Timer.instance == null) {
                Pomodoro.Timer.instance = null;
            }
        }

        /**
         * Try to change state and update fields related to state change
         */
        public void set_state_full (Pomodoro.TimerState state,
                                    int64               timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            this.ensure_timestamp (ref timestamp);

            var previous_state = this._state;

            this.resolve_state_internal (ref state, timestamp);

            if (!state.is_valid ()) {
                GLib.error ("Trying to set timer an invalid state: %s", state.to_representation ());
            }

            if (this._state.equals (state)) {
                return;
            }

            this.last_state_changed_time = timestamp;
            this._state = state;

            // Reset internal ticking interval, so that it aligns to seconds after skipping or rewinding.
            if (state.started_time != previous_state.started_time ||
                state.offset != previous_state.offset)
            {
                this.stop_timeout (timestamp);
            }

            this.notify_property ("state");

            if (state.duration != previous_state.duration) {
                this.notify_property ("duration");
            }

            if (state.started_time != previous_state.started_time) {
                this.notify_property ("started-time");
            }

            if (state.offset != previous_state.offset) {
                this.notify_property ("offset");
            }

            if (state.user_data != previous_state.user_data) {
                this.notify_property ("user-data");
            }

            this.state_changed (this._state, previous_state);
        }

        /**
         * Resolve timer state.
         *
         * It's a wrapper for `this.resolve_state`, handling a possible recursion.
         */
        private void resolve_state_internal (ref Pomodoro.TimerState state,
                                             int64                   timestamp)
        {
            var recursion_count = 0;

            if (this.resolving_state) {
                this.state_to_resolve = state;
                return;
            }

            if (this._state.equals (state)) {
                return;
            }

            this.resolving_state = true;

            while (true)
            {
                this.resolve_state (ref state, timestamp);

                if (this.state_to_resolve == null) {
                    break;
                }

                if (recursion_count > 1) {
                    GLib.error ("Reached recursion limit while resolving timer state");
                }

                state = this.state_to_resolve;
                this.state_to_resolve = null;

                recursion_count++;
            }

            this.resolving_state = false;
        }


        /**
         * Sets a default `Timer`.
         *
         * The old default timer is unreffed and the new timer referenced.
         *
         * A value of null for this will cause the current default timer to be released and a new default timer
         * to be created on demand.
         */
        public static void set_default (Pomodoro.Timer? timer)
        {
            Pomodoro.Timer.instance = timer;
        }

        /**
         * Return a default timer.
         *
         * A new default timer will be created on demand.
         */
        public static unowned Pomodoro.Timer get_default ()
        {
            if (Pomodoro.Timer.instance == null) {
                Pomodoro.Timer.set_default (new Pomodoro.Timer ());
            }

            return Pomodoro.Timer.instance;
        }

        public bool is_default ()
        {
            return Pomodoro.Timer.instance == this;
        }


        /**
         * Return whether timer is ticking -- whether timer has started, is not paused and hasn't finished.
         */
        public bool is_running ()
        {
            return Pomodoro.Timestamp.is_defined (this._state.started_time) &&
                   Pomodoro.Timestamp.is_undefined (this._state.paused_time) &&
                   Pomodoro.Timestamp.is_undefined (this._state.finished_time);
        }

        /**
         * Return whether timer has been started.
         */
        public bool is_started ()
        {
            return Pomodoro.Timestamp.is_defined (this._state.started_time);
        }

        /**
         * Return whether timer is paused.
         */
        public bool is_paused ()
        {
            return Pomodoro.Timestamp.is_defined (this._state.paused_time) &&
                   Pomodoro.Timestamp.is_defined (this._state.started_time) &&
                   Pomodoro.Timestamp.is_undefined (this._state.finished_time);
        }

        /**
         * Return whether timer has finished.
         *
         * It does not need to reach full time for timer to be marked as finished.
         */
        public bool is_finished ()
        {
            return Pomodoro.Timestamp.is_defined (this._state.finished_time);
        }

        /**
         * Reset timer to initial state.
         */
        public void reset (int64 duration = 0,
                           void* user_data = null)
                           requires (duration >= 0)
        {
            this.set_state_full (
                Pomodoro.TimerState () {
                    duration = duration,
                    offset = 0,
                    started_time = Pomodoro.Timestamp.UNDEFINED,
                    paused_time = Pomodoro.Timestamp.UNDEFINED,
                    finished_time = Pomodoro.Timestamp.UNDEFINED,
                    user_data = user_data
                }
            );
        }

        /**
         * Start the timer or continue where it left off.
         */
        public void start (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this.is_started () || this.is_finished ()) {
                return;
            }

            this.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.started_time = timestamp;
            new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            this.set_state_full (new_state, timestamp);
        }

        /**
         * Stop the timer if it's running.
         */
        public void pause (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this.is_paused () || !this.is_started () || this.is_finished ()) {
                return;
            }

            this.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.paused_time = this.round_seconds (timestamp);

            this.set_state_full (new_state, timestamp);
        }

        /**
         * Resume timer if paused.
         */
        public void resume (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (!this.is_started () || this.is_finished () || !this.is_paused ()) {
                return;
            }

            this.ensure_timestamp (ref timestamp);

            var new_state = this._state.copy ();
            new_state.offset += timestamp - new_state.paused_time;
            new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            this.set_state_full (new_state, timestamp);
        }

        /**
         * Rewind
         */
        public void rewind (int64 interval,
                            int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (!this.is_started ()) {
                return;
            }

            if (interval == 0) {
                return;
            }

            if (interval < 0) {
                GLib.debug ("Rewinding timer with negative value (%.1fs).",
                            Pomodoro.Timestamp.to_seconds (interval));
            }

            this.ensure_timestamp (ref timestamp);

            var elapsed = this.calculate_elapsed (timestamp);
            var new_elapsed = Pomodoro.Timestamp.round (int64.max (elapsed - interval, 0), TICKING_INTERVAL);
            var new_state = this._state.copy ();

            new_state.finished_time = Pomodoro.Timestamp.UNDEFINED;

            if (Pomodoro.Timestamp.is_defined (new_state.paused_time)) {
                new_state.offset = new_state.paused_time - new_state.started_time - new_elapsed;
            }
            else {
                new_state.offset = timestamp - new_state.started_time - new_elapsed;
            }

            this.set_state_full (new_state, timestamp);
        }

        /**
         * Mark state as "finished".
         */
        private void finish (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this.is_finished ()) {
                return;
            }

            this.ensure_timestamp (ref timestamp);

            this.stop_timeout (timestamp);

            var new_state = this._state.copy ();
            new_state.finished_time = timestamp;

            if (Pomodoro.Timestamp.is_defined (new_state.paused_time)) {
                new_state.offset += timestamp - new_state.paused_time;
                new_state.paused_time = Pomodoro.Timestamp.UNDEFINED;
            }

            this.set_state_full (new_state, timestamp);
        }

        public void synchronize (int64 monotonic_time = Pomodoro.Timestamp.UNDEFINED,
                                 int64 real_time = Pomodoro.Timestamp.UNDEFINED)
        {
            if (Pomodoro.Timestamp.is_undefined (real_time)) {
                real_time = Pomodoro.Timestamp.from_now ();
            }

            if (Pomodoro.Timestamp.is_undefined (monotonic_time)) {
                monotonic_time = GLib.get_monotonic_time ();
            }

            this.monotonic_time_offset = real_time - monotonic_time;

            this.synchronized ();
        }

        /**
         * Return approximate real time.
         */
        public int64 get_current_time (int64 monotonic_time = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this.monotonic_time_offset == 0 || Pomodoro.Timestamp.is_frozen ()) {
                return Pomodoro.Timestamp.from_now ();
            }
            else {
                if (Pomodoro.Timestamp.is_undefined (monotonic_time)) {
                    monotonic_time = GLib.get_monotonic_time ();
                }

                return monotonic_time + this.monotonic_time_offset;
            }
        }

        private int64 round_seconds (int64 timestamp)
        {
            if (this.last_tick_time > 0 &&
                (timestamp - this.last_tick_time).abs () < 2 * TICKING_INTERVAL)
            {
                return this.last_tick_time;
            }

            if (Pomodoro.Timestamp.is_defined (this._state.started_time))
            {
                var elapsed = this.calculate_elapsed (timestamp);
                var elapsed_rounded = Pomodoro.Timestamp.round (elapsed, TICKING_INTERVAL);

                return this._state.started_time + this._state.offset + elapsed_rounded;
            }

            return timestamp;
        }

        private inline void ensure_timestamp (ref int64 timestamp)
        {
            if (Pomodoro.Timestamp.is_undefined (timestamp)) {
                timestamp = this.get_current_time ();
            }
        }

        private int64 calculate_tick_time (int64 timestamp)
        {
            var elapsed = this.calculate_elapsed (timestamp);
            var elapsed_rounded = Pomodoro.Timestamp.round (elapsed, TICKING_INTERVAL);

            return Pomodoro.Timestamp.is_defined (this._state.started_time)
                ? this._state.started_time + this._state.offset + elapsed_rounded
                : Pomodoro.Timestamp.UNDEFINED;
        }

        /**
         * Ticking timeout.
         *
         * Unfortunately it can deviate from full seconds.
         */
        private bool on_timeout ()
                                      requires (this.timeout_id != 0)
        {
            var timestamp         = this.get_current_time (GLib.MainContext.current_source ().get_time ());
            var timestamp_rounded = this.calculate_tick_time (timestamp);
            var remaining         = this.calculate_remaining (timestamp);

            if (remaining > 0 && this.last_tick_time != timestamp_rounded) {
                this.last_tick_time = timestamp_rounded;
                this.tick (timestamp_rounded);
            }

            // Check if already finished.
            if (remaining < TICKING_TOLERANCE) {
                this.timeout_id = 0;
                this.finish (timestamp);

                return GLib.Source.REMOVE;
            }

            // Check whether to switch to a more precise timeout.
            if (remaining < TICKING_INTERVAL + TICKING_TOLERANCE)
            {
                this.timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (remaining),
                                                    this.on_timeout_once);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout_once");

                return GLib.Source.REMOVE;
            }

            return GLib.Source.CONTINUE;
        }

        /**
         * Precise timeout.
         *
         * It's meant to setup idle timeout that is aligned to full seconds.
         */
        private bool on_timeout_once ()
                                 requires (this.timeout_id != 0)
        {
            var timestamp         = this.get_current_time (GLib.MainContext.current_source ().get_time ());
            var timestamp_rounded = this.calculate_tick_time (timestamp);
            var remaining         = this.calculate_remaining (timestamp);

            this.timeout_id = 0;

            if (remaining > 0 && this.last_tick_time != timestamp_rounded) {
                this.last_tick_time = timestamp_rounded;
                this.tick (timestamp_rounded);
            }

            // Check if already finished.
            if (remaining < TICKING_TOLERANCE) {
                this.finish (timestamp);

                return GLib.Source.REMOVE;
            }

            // Close to finish. Schedule one more timeout instead of interval.
            if (remaining < TICKING_INTERVAL + TICKING_TOLERANCE) {
                this.timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (remaining),
                                                    this.on_timeout_once);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout_once");

                return GLib.Source.REMOVE;
            }

            // Schedule ticking at regular interval.
            this.timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (TICKING_INTERVAL),
                                                this.on_timeout);
            GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout");

            return GLib.Source.REMOVE;
        }

        /**
         * Start ticking. First tick will be emitted after the `interval`.
         *
         * `aligned` will align ticks to elapsed time. It's meant for displaying elapsed/remaining time to sync label
         * updates with the timer.
         */
        private void start_timeout_internal (int64 timestamp)
                                             requires (Pomodoro.Timestamp.is_defined (timestamp))
                                             requires (this.timeout_id == 0)
        {
            var timestamp_rounded = this.calculate_tick_time (timestamp);
            var remaining         = this.calculate_remaining (timestamp);

            this.last_tick_time = timestamp_rounded;

            if (remaining > TICKING_TOLERANCE)
            {
                var is_ticking = this.tick_freeze_count <= 0;
                var deviation  = timestamp - timestamp_rounded;

                if (is_ticking &&
                    remaining > TICKING_INTERVAL &&
                    deviation.abs () < TICKING_TOLERANCE)
                {
                    this.timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (TICKING_INTERVAL),
                                                        this.on_timeout);
                    GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout");
                }
                else {
                    this.timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (is_ticking ? TICKING_INTERVAL - deviation : remaining),
                                                        this.on_timeout_once);
                    GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.Timer.on_timeout_once");
                }
            }
            else {
                this.finish (timestamp);
            }
        }

        private void start_timeout (int64 timestamp)
        {
            if (this.timeout_id != 0 ) {
                return;  // already running
            }

            if (Pomodoro.Timestamp.is_frozen ()) {
                return;  // don't run timeout in unittests
            }

            this.synchronize (Pomodoro.Timestamp.UNDEFINED, timestamp);

            this.start_timeout_internal (timestamp);
        }

        private void stop_timeout (int64 timestamp)
        {
            // State may change right before a timeout callback gets called.
            // Ensure that tick gets emitted if it's delayed.
            var timestamp_rounded = this.calculate_tick_time (timestamp);

            if (this.last_tick_time != timestamp_rounded && timestamp_rounded >= this.last_state_changed_time) {
                this.last_tick_time = timestamp_rounded;
                this.tick (timestamp_rounded);
            }

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.monotonic_time_offset = 0;
            this.last_tick_time = Pomodoro.Timestamp.UNDEFINED;
        }

        /**
         * Increment freeze counter for tick signal.
         */
        public void freeze_tick ()
        {
            this.tick_freeze_count++;
        }

        /**
         * Decrease freeze counter for tick signal.
         */
        public void thaw_tick ()
        {
            this.tick_freeze_count--;
        }

        /**
         * Return time of a last state change.
         *
         * It's deliberate that "last_state_changed_time" is not a property, as we don't want emitting
         * notify events for that.
         */
        public int64 get_last_state_changed_time ()
        {
            return this.last_state_changed_time;
        }

        public int64 get_last_tick_time ()
        {
            return this.last_tick_time;
        }

        /**
         * Calculate elapsed time.
         *
         * It's only accurate when passing a current time. If you pass a historic time
         * the result will be just an estimate.
         */
        public int64 calculate_elapsed (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (Pomodoro.Timestamp.is_undefined (this._state.started_time)) {
                return 0;
            }

            this.ensure_timestamp (ref timestamp);

            if (Pomodoro.Timestamp.is_defined (this._state.paused_time)) {
                timestamp = int64.min (this._state.paused_time, timestamp);
            }

            if (Pomodoro.Timestamp.is_defined (this._state.finished_time)) {
                timestamp = int64.min (this._state.finished_time, timestamp);
            }

            return (
                timestamp - this._state.started_time - this._state.offset
            ).clamp (0, this._state.duration);
        }

        /**
         * Calculate remaining time.
         *
         * It's only accurate when passing a current time. If you pass a historic time
         * the result will be just an estimate.
         */
        public int64 calculate_remaining (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            return this._state.duration - this.calculate_elapsed (timestamp);
        }

        /**
         * Calculate progress.
         *
         * It's only accurate when passing a current time. If you pass a historic time
         * the result will be just an estimate.
         */
        public double calculate_progress (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            var elapsed = (double) this.calculate_elapsed (timestamp);
            var duration = (double) this._state.duration;

            return duration > 0.0 ? elapsed / duration : 0.0;
        }

        /**
         * Calculate finish time.
         *
         * When paused it returns `Timestamp.UNDEFINED`.
         */
        public int64 calculate_finish_time ()
        {
            if (!this.is_running ()) {
                return Pomodoro.Timestamp.UNDEFINED;
            }

            if (this.is_finished ()) {
                return this._state.finished_time;
            }

            return this._state.started_time + this._state.offset + this._state.duration;
        }

        /**
         * Wait until timer finishes
         *
         * It will only have an effect after Timer.start() or after setting up timer state.
         *
         * Intended for unit tests.
         */
        public void run (GLib.Cancellable? cancellable = null)
        {
            var main_context = GLib.MainContext.@default ();

            while (this.is_running () && (cancellable == null || !cancellable.is_cancelled ()))
            {
                main_context.iteration (true);
            }
        }

        /**
         * Manually perform a tick or check whether timer has finished.
         *
         * Intended for unit tests.
         */
        public void iterate ()
        {
            var timestamp         = Pomodoro.Timestamp.peek ();
            var timestamp_rounded = this.calculate_tick_time (timestamp);
            var remaining         = this.calculate_remaining (timestamp);

            if (remaining > 0 && this.last_tick_time != timestamp_rounded) {
                this.last_tick_time = timestamp_rounded;
                this.tick (timestamp_rounded);
            }

            if (remaining < TICKING_TOLERANCE) {
                this.finish (timestamp);
            }
        }

        /**
         * Emitted before setting a new state.
         *
         * It allows for fine-tuning the state before emitting state-changed signal.
         * Default handler ensures that state is valid.
         */
        public signal void resolve_state (ref Pomodoro.TimerState state,
                                          int64                   timestamp)
        {
            if (Pomodoro.Timestamp.is_undefined (state.started_time)) {
                state.paused_time = Pomodoro.Timestamp.UNDEFINED;
                state.finished_time = Pomodoro.Timestamp.UNDEFINED;
            }

            if (Pomodoro.Timestamp.is_defined (state.paused_time) && state.paused_time < state.started_time) {
                state.paused_time = state.started_time;
            }

            if (Pomodoro.Timestamp.is_defined (state.finished_time) && state.finished_time < state.started_time) {
                state.finished_time = state.started_time;
            }
        }

        /**
         * Emitted on any state related changes. Default handler acknowledges the change.
         */
        [Signal (run = "first")]
        public signal void state_changed (Pomodoro.TimerState current_state,
                                          Pomodoro.TimerState previous_state)
        {
            if (this.is_running ()) {
                this.start_timeout (this.last_state_changed_time);
            }
            else {
                this.stop_timeout (this.last_state_changed_time);
            }

            if (Pomodoro.Timestamp.is_defined (current_state.finished_time) &&
                Pomodoro.Timestamp.is_undefined (previous_state.finished_time))
            {
                this.finished (current_state);
            }
        }

        /**
         * Emitted every second when timer is running.
         *
         * Ticks are aligned to full seconds of elapsed time.
         */
        public signal void tick (int64 timestamp);

        /**
         * Emitted when countdown is close to zero or passed it.
         */
        public signal void finished (Pomodoro.TimerState state);

        /**
         * Emitted after synchronizing timer against monotonic time.
         */
        public signal void synchronized ();

        /**
         * Emitted right after system wakes up and the timer synchronizes.
         */
        [Signal (run = "last")]
        public signal void suspended (int64 start_time,
                                      int64 end_time)
        {
            if (this.last_state_changed_time > start_time) {
                // Signal handler pushed a new state.
                return;
            }

            if (this.is_running ())
            {
                var new_state = this._state.copy ();
                new_state.offset += end_time - start_time;

                this.set_state_full (new_state, end_time);
            }
        }

        public override void dispose ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            if (this.prepare_for_sleep_id != 0) {
                this.sleep_monitor.disconnect (this.prepare_for_sleep_id);
                this.prepare_for_sleep_id = 0;
            }

            if (this.woke_up_id != 0) {
                this.sleep_monitor.disconnect (this.woke_up_id);
                this.woke_up_id = 0;
            }

            this.sleep_monitor = null;

            base.dispose ();
        }
    }
}
