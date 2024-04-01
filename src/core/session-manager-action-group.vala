/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 */

using GLib;


namespace Pomodoro
{
    public class SessionManagerActionGroup : GLib.SimpleActionGroup
    {
        public Pomodoro.SessionManager session_manager {
            get {
                return this._session_manager;
            }
            construct {
                this._session_manager = value;

                this.notify_current_time_block_id = this._session_manager.notify["current-time-block"].connect (
                    this.on_notify_current_time_block);

                this.session_expired_id = this._session_manager.session_expired.connect (this.on_session_expired);
            }
        }

        private Pomodoro.SessionManager _session_manager;
        private GLib.SimpleAction       state_action;
        private GLib.SimpleAction       start_short_break_action;
        private GLib.SimpleAction       start_long_break_action;
        private GLib.SimpleAction       start_break_action;
        private ulong                   notify_current_time_block_id = 0;
        private ulong                   session_expired_id = 0;


        public SessionManagerActionGroup ()
        {
            GLib.Object (
                session_manager: Pomodoro.SessionManager.get_default ()
            );
        }

        construct
        {
            var advance_action = new GLib.SimpleAction ("advance", null);
            advance_action.activate.connect (this.activate_advance);
            this.add_action (advance_action);

            var reset_action = new GLib.SimpleAction ("reset", null);
            reset_action.activate.connect (this.activate_reset);
            this.add_action (reset_action);

            // var skip_break_action = new GLib.SimpleAction ("skip-break", null);
            // skip_break_action.activate.connect (this.activate_skip_break);
            // this.add_action (skip_break_action);

            var state_action = new GLib.SimpleAction.stateful ("state",
                                                               GLib.VariantType.STRING,
                                                               new GLib.Variant.string (this.get_current_state ()));
            state_action.activate.connect (this.activate_state);
            this.add_action (state_action);

            var start_pomodoro_action = new GLib.SimpleAction ("start-pomodoro", null);
            start_pomodoro_action.activate.connect (this.activate_start_pomodoro);
            this.add_action (start_pomodoro_action);

            var start_short_break_action = new GLib.SimpleAction ("start-short-break", null);
            start_short_break_action.activate.connect (this.activate_start_short_break);
            this.add_action (start_short_break_action);

            var start_long_break_action = new GLib.SimpleAction ("start-long-break", null);
            start_long_break_action.activate.connect (this.activate_start_long_break);
            this.add_action (start_long_break_action);

            var start_break_action = new GLib.SimpleAction ("start-break", null);
            start_break_action.activate.connect (this.activate_start_break);
            this.add_action (start_break_action);

            this.state_action = state_action;
            this.start_short_break_action = start_short_break_action;
            this.start_long_break_action = start_long_break_action;
            this.start_break_action = start_break_action;
        }

        private string get_current_state ()
        {
            var current_time_block = this.session_manager.current_time_block;
            var current_state = current_time_block != null ? current_time_block.state : Pomodoro.State.UNDEFINED;

            return current_state.to_string ();
        }

        private void activate_advance (GLib.SimpleAction action,
                                       GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("session-manager.advance");
            this.session_manager.advance ();
        }

        // private void activate_skip_break (GLib.SimpleAction action,
        //                                   GLib.Variant?     parameter)
        // {
        //     var current_time_block = this.session_manager.current_time_block;
        //     var current_state = current_time_block != null ? current_time_block.state : Pomodoro.State.UNDEFINED;

        //     if (current_state.is_break () || this.session_manager.timer.is_finished ())
        //     {
        //         this.session_manager.advance_to_state (Pomodoro.State.POMODORO);
        //     }
        // }

        private void activate_reset (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("session-manager.reset");
            this.session_manager.reset ();
        }

        private void activate_state (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            if (parameter == null) {
                return;
            }

            Pomodoro.Context.set_event_source (@"session-manager.state:$(parameter.get_string())");
            this.session_manager.advance_to_state (Pomodoro.State.from_string (parameter.get_string ()));
        }

        private void activate_start_pomodoro (GLib.SimpleAction action,
                                              GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("session-manager.start-pomodoro");
            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);
        }

        private void activate_start_short_break (GLib.SimpleAction action,
                                                 GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("session-manager.start-short-break");
            this.session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);
        }

        private void activate_start_long_break (GLib.SimpleAction action,
                                                GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("session-manager.start-long-break");
            this.session_manager.advance_to_state (Pomodoro.State.LONG_BREAK);
        }

        private void activate_start_break (GLib.SimpleAction action,
                                           GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("session-manager.start-break");
            this.session_manager.advance_to_state (Pomodoro.State.BREAK);
        }

        private void on_notify_current_time_block ()
        {
            this.state_action.set_state (new Variant.string (this.get_current_state ()));
        }

        private void on_session_expired (Pomodoro.Session session,
                                         int64            timestamp)
        {
            Pomodoro.Context.set_event_source ("session-manager.session-expired", timestamp);
        }

        public override void dispose ()
        {
            if (this.notify_current_time_block_id != 0) {
                this._session_manager.disconnect (this.notify_current_time_block_id);
                this.notify_current_time_block_id = 0;
            }

            if (this.session_expired_id != 0) {
                this._session_manager.disconnect (this.session_expired_id);
                this.session_expired_id = 0;
            }

            this.state_action = null;
            this.start_short_break_action = null;
            this.start_long_break_action = null;
            this.start_break_action = null;
            this._session_manager = null;

            base.dispose ();
        }
    }
}
