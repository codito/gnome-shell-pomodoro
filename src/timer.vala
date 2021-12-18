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
    /**
     * Helper structure to track change of several properties at once.
     * Most values here are meant to be frozen, that's why some values from `time_block` are copied here.
     * If timer gets paused or the time block gets updated, we will build a new state.
     *
     * Notice that we consider `is_paused` as part of state, and that `duration` is intended duration,
     * not the real one as in time block.
     */
    private struct TimerState
    {
        public Pomodoro.Session   session;  // TODO: remove, use time_block.session
        public Pomodoro.TimeBlock time_block;
        public Pomodoro.State     state;
        public int64              timestamp;
        public int64              duration;
        public int64              offset;
        public bool               is_paused;

        public static TimerState with_time_block (Pomodoro.TimeBlock time_block,
                                                  int64              offset = 0)
        {
            return Pomodoro.TimerState () {
                session = time_block.session,
                time_block = time_block,
                state = time_block.state,
                timestamp = time_block.start,
                duration = int64.max (time_block.duration - offset, 0),
                offset = offset,
                is_paused = false
            };
        }

        // public Pomodoro.TimerState copy ()
        // {
        //     return Pomodoro.TimerState () {
        //         session = this.session,
        //         time_block = this.time_block,
        //         state = this.state,
        //         timestamp = this.timestamp,
        //         duration = this.duration,
        //         offset = this.offset,
        //         is_paused = this.is_paused
        //     };
        // }
    }


    /**
     * Timer class helps to trigger event after a period of time.
     */
    public class Timer : GLib.Object
    {
        private static unowned Pomodoro.Timer? instance = null;

        public unowned Pomodoro.Session session {
            get {
                return this.internal_state.session;
            }
        }

        public unowned Pomodoro.TimeBlock time_block {
            get {
                return this.internal_state.time_block;
            }
        }

        /**
         * Main pomodoro state. Whetherer working or taking a break.
         */
        public Pomodoro.State state {
            get {
                return this.internal_state.time_block.state;
            }
        }

        /**
         * The intended state duration
         */
        public int64 duration {
            get {
                return this.internal_state.duration;
            }
            set {
                if (this.state == Pomodoro.State.UNDEFINED) {
                    return;
                }

                // TODO: - edit the time_block
                //       - editing the timeblock should trigger new TimerState
                //       - new state should trigger roprty notification

                // var new_state = this.internal_state.copy ();
                // new_state.duration += value;

                // this.push_state (new_state);
            }
        }

        public int64 timestamp {
            get {
                return this.internal_state.timestamp;
            }
        }

        public int64 offset {
            get {
                return this.internal_state.offset;
            }
        }

        // There is a family of similar properties is_stopped, is_paused, is_running,
        // so, to unify them they are all methods now.
        // TODO: alternative would be two properties: is_running and is_paused, is_stopped
        // public bool is_paused {
        //     get {
        //         return this.internal_state.is_paused;
        //     }
        //     set {
        //         if (value) {
        //             this.pause ();
        //         }
        //         else {
        //             this.resume ();
        //         }
        //     }
        // }

        private Pomodoro.TimerState internal_state;
        private uint timeout_source = 0;

        ~Timer ()
        {
            if (Pomodoro.Timer.instance == null) {
                Pomodoro.Timer.instance = null;
            }
        }

        construct
        {
            var session = new Pomodoro.Session ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED,
                                                     Pomodoro.Timestamp.from_now ());
            session.add_time_block (time_block);

            this.internal_state = Pomodoro.TimerState () {
                session = time_block.session,
                time_block = time_block,
                timestamp = time_block.start,
                state = time_block.state
            };
        }

        public static unowned Pomodoro.Timer get_default ()
        {
            if (Pomodoro.Timer.instance == null) {
                var timer = new Pomodoro.Timer ();
                timer.set_default ();
            }

            return Pomodoro.Timer.instance;
        }

        public void set_default ()
        {
            Pomodoro.Timer.instance = this;

            // timer.watch_closure (() => {
            //     if (Pomodoro.Timer.instance == timer) {
            //         Pomodoro.Timer.instance = null;
            //     }
            // });
        }

        /*
        public int64 get_elapsed (int64 timestamp = Pomodoro.get_current_timestamp ())
        {
            return this.timestamp - - this.gap_time;
        }

        public int64 get_remaining (int64 timestamp = Pomodoro.get_current_timestamp ())
        {
            return this.timestamp - - this.gap_time;
        }
        */

        /**
         * Check whether timer is stopped.
         */
        public bool is_stopped ()
        {
            return this.internal_state.state == Pomodoro.State.UNDEFINED;
        }

        /**
         * Check whether timer has been paused.
         */
        public bool is_paused ()  // TODO: remove is_paused/pause/resume. Timer.ticking
        {
            return this.internal_state.is_paused;
        }

        /**
         * Check whether timer is ticking.
         */
        public bool is_running ()
        {
            return !(this.is_stopped () || this.is_paused ());
        }

        public void start (int64 timestamp = Pomodoro.get_current_time ())
        {
            // this.resume (timestamp);

            if (this.internal_state.state == Pomodoro.State.UNDEFINED) {
                this.set_state (Pomodoro.State.POMODORO, timestamp);
            }

            // if (this.internal_state.state == Pomodoro.State.UNDEFINED) {
            //     var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            //
            //     this.internal_state = new Pomodoro.TimerState.with_time_block (time_block, timestamp);
            // }
        }

        public void stop (int64 timestamp = Pomodoro.get_current_time ())
        {
            // this.resume (timestamp);

            this.set_state (Pomodoro.State.UNDEFINED, timestamp);

            // if (this.internal_state.state != Pomodoro.State.UNDEFINED) {
            //     this.state = new Pomodoro.DisabledState.with_timestamp (timestamp);
            // }
        }

        // TODO: remove
        public void toggle (int64 timestamp = Pomodoro.get_current_time ())
        {
            if (this.internal_state.state == Pomodoro.State.UNDEFINED) {
                this.start (timestamp);
            }
            else {
                this.stop (timestamp);
            }
        }

        public void pause (int64 timestamp = Pomodoro.get_current_time ())
        {
            this.set_is_paused_full (true, timestamp);
        }

        public void resume (int64 timestamp = Pomodoro.get_current_time ())
        {
            this.set_is_paused_full (false, timestamp);
        }

        public void skip (int64 timestamp = Pomodoro.get_current_time ())
        {
            // jump to end

            // this.internal_state = this.internal_state.create_next_state (this.score, timestamp);
        }

        public void rewind (int64 duration,  // TODO specify time_block
                            int64 timestamp = Pomodoro.get_current_time ())
        {
            // TODO: handle rewinding to previous state
            var offset_reference = this.internal_state.duration + this.internal_state.offset;

            // TODO: push new internal_state
            this.internal_state.offset = int64.max (offset_reference - duration, 0) - offset_reference;
        }

        /**
         * set_state
         *
         * Changes the state and sets new timestamp
         */
        public void set_state (Pomodoro.State state,
                               int64          timestamp = -1)
        {
            // TODO

            // var previous_state = this.internal_state;

            // this.timestamp = timestamp;

            // this.state_leave (this.internal_state);

            // this.internal_state = state;
            // this.update_offset ();

            // this.state_enter (this.internal_state);

            // if (!this.resolve_state ()) {
            //     this.state_changed (this.internal_state, previous_state);
            // }
        }

        private void set_is_paused_full (bool  value,
                                         int64 timestamp)
        {
            if (value && this.timeout_source == 0) {
                return;
            }

            if (value != this.internal_state.is_paused) {
                // TODO: push new state
                this.internal_state.is_paused = value;
                this.internal_state.timestamp = timestamp;

                this.update_offset ();
                this.update_timeout ();

                // this.notify_property ("is-paused");
            }
        }

        private bool on_timeout ()
        {
            // TODO: check if computer has been suspended

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
            // TODO: schedule secondary timeout when it's close to end

            if (this.timeout_source == 0) {
                this.timeout_source = GLib.Timeout.add (1000, this.on_timeout);
            }
        }

        private void update_timeout ()
        {
            if (this.internal_state.state == Pomodoro.State.UNDEFINED || this.internal_state.is_paused) {
                this.stop_timeout ();
            }
            else {
                this.start_timeout ();
            }
        }

        private void update_offset (int64 timestamp = -1)
        {
            // TODO: we sould push new state

            if (timestamp < 0) {
                timestamp = Pomodoro.Timestamp.from_now ();
            }

            this.internal_state.offset = (timestamp - this.internal_state.timestamp) - this.get_elapsed (timestamp);
        }

        // TODO: remove
        public GLib.ActionGroup get_action_group ()
        {
            return Pomodoro.TimerActionGroup.for_timer (this);
        }

        public int64 get_elapsed (int64 timestamp = -1)
        {
            return this.time_block.get_elapsed (timestamp);
        }

        public int64 get_remaining (int64 timestamp = -1)
        {
            return this.time_block.get_remaining (timestamp);
        }

        public double get_progress (int64 timestamp = -1)
        {
            return this.time_block.get_progress (timestamp);
        }

        public double get_session_progress (int64 timestamp = -1)
        {
            return this.time_block.session.get_progress (timestamp);
        }

        /**
         * Unref default instance.
         */
        public void destroy ()
        {
            if (Pomodoro.Timer.instance == this) {
                Pomodoro.Timer.instance = null;
            }
        }

        public override void dispose ()
        {
            if (this.timeout_source != 0) {
                GLib.Source.remove (this.timeout_source);
                this.timeout_source = 0;
            }

            base.dispose ();
        }

        /**
         * Emitted on any state related change:
         * - change of state
         * - change of duration
         * - pause/resume
         */
        public signal void changed ();


        // public signal void stopped ();


        /**
         * Achieved score or number of completed pomodoros.
         *
         * It's updated on state change.
         */
        // public double score {
        //     get; set; default = 0.0;
        // }
        // private bool _is_paused;

        // public int64 calculate_elapsed (int64 timestamp)  // TODO: rename to get_elapsed once property is removed
        // {
        //     return timestamp - (int64)(this.internal_state.timestamp * 1000.0) - (int64)(this._offset * 1000.0);
        // }

        // public double calculate_state_progress (int64 timestamp)  // TODO: move it to State class
        // {
        //     if (this.state_duration <= 0.0) {
        //         return 0.0;
        //     }

        //     warning ( "### %.6f %.6f", ((double) timestamp) / USEC_PER_SEC, this.internal_state.timestamp);

        //     return (
        //         ((double) timestamp) / USEC_PER_SEC - this.internal_state.timestamp - this._offset
        //     ) / this.state_duration;
        // }

        // public double calculate_elapsed_double (int64 timestamp)  // TODO: rename to get_elapsed once property is removed
        // {
        //     return ((double) this.calculate_elapsed_double (timestamp)) / 1000.0;
        // }

        // deprecated, use state.duration
        // [CCode (notify = false)]
        // public double state_duration {
        //     get {
        //         return this.internal_state != null ? this.internal_state.duration : 0.0;
        //     }
        //     set {
        //         if (this.internal_state != null) {
        //             this.internal_state.duration = value;
        //         }
        //     }
        // }
    }
}
