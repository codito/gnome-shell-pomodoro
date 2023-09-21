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
                    () => {
                        this.state_action.set_state (new Variant.string (this.get_current_state ()));
                    }
                );
            }
        }

        private Pomodoro.SessionManager _session_manager;
        private GLib.SimpleAction       state_action;
        private ulong                   notify_current_time_block_id = 0;

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

            var state_action = new GLib.SimpleAction.stateful ("state",
                                                               GLib.VariantType.STRING,
                                                               new GLib.Variant.string (this.get_current_state ()));
            state_action.activate.connect (this.activate_state);
            this.add_action (state_action);

            this.state_action = state_action;
        }

        private string get_current_state ()
        {
            var current_time_block = this.session_manager.current_time_block;
            var state = current_time_block != null ? current_time_block.state : Pomodoro.State.UNDEFINED;

            return state.to_string ();
        }

        private void activate_advance (GLib.SimpleAction action,
                                       GLib.Variant?     parameter)
        {
            this.session_manager.advance ();
        }

        private void activate_reset (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.session_manager.reset ();
        }

        private void activate_state (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            if (parameter == null) {
                return;
            }

            this.session_manager.advance_to_state (Pomodoro.State.from_string (parameter.get_string ()));
        }

        public override void dispose ()
        {
            if (this.notify_current_time_block_id != 0) {
                this.session_manager.disconnect (notify_current_time_block_id);
                this.notify_current_time_block_id = 0;
            }

            this.state_action = null;

            base.dispose ();
        }
    }
}
