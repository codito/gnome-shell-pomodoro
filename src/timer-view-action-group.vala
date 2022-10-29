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
        public Pomodoro.SessionManager session_manager { get; construct; }

        public SessionManagerActionGroup (Pomodoro.SessionManager session_manager)
        {
            GLib.Object (
                session_manager: session_manager
            );
        }
    }


    public class TimerActionGroup : GLib.SimpleActionGroup
    {
        public Pomodoro.Timer timer { get; construct; }

        private GLib.SimpleAction start_action;
        private GLib.SimpleAction reset_action;
        private GLib.SimpleAction pause_action;
        private GLib.SimpleAction resume_action;
        private GLib.SimpleAction skip_action;
        private GLib.SimpleAction state_action;
        private GLib.SimpleAction skip_action;
        private GLib.SimpleAction rewind_action;

        private ulong timer_state_changed_id = 0;

        public TimerActionGroup (Pomodoro.Timer timer)
        {
            GLib.Object (
                timer: timer
            );

            this.timer_state_changed_id = timer.state_changed.connect (this.on_timer_changed);
        }

        construct
        {
            this.start_action = new GLib.SimpleAction ("start", null);
            this.start_action.activate.connect (this.activate_start);
            this.add_action (this.start_action);

            this.reset_action = new GLib.SimpleAction ("reset", null);
            this.reset_action.activate.connect (this.activate_reset);
            this.add_action (this.reset_action);

            this.pause_action = new GLib.SimpleAction ("pause", null);
            this.pause_action.activate.connect (this.activate_pause);
            this.add_action (this.pause_action);

            this.resume_action = new GLib.SimpleAction ("resume", null);
            this.resume_action.activate.connect (this.activate_resume);
            this.add_action (this.resume_action);

            this.skip_action = new GLib.SimpleAction ("skip", null);
            this.skip_action.activate.connect (this.activate_skip);
            this.add_action (this.skip_action);

            this.rewind_action = new GLib.SimpleAction ("rewind", null);
            this.rewind_action.activate.connect (this.activate_rewind);
            this.add_action (this.rewind_action);

            this.update_action_states ();
        }

        private void update_action_states ()
        {
            var is_started = this.timer.is_started ();
            var is_paused = this.timer.is_paused ();

            this.start_action.set_enabled (!is_started);
            this.reset_action.set_enabled (is_started);
            this.pause_action.set_enabled (is_started && !is_paused);
            this.resume_action.set_enabled (is_started && is_paused);
            this.skip_action.set_enabled (is_started);
            this.rewind_action.set_enabled (is_started);
        }

        private void on_timer_changed (Pomodoro.TimerState current_state,
                                       Pomodoro.TimerState previous_state)
        {
            this.update_action_states ();
        }

        private void activate_start (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.timer.start ();
        }

        private void activate_reset (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.timer.reset ();
        }

        private void activate_pause (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.timer.pause ();
        }

        private void activate_resume (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            this.timer.resume ();
        }

        private void activate_skip (GLib.SimpleAction action,
                                    GLib.Variant?     parameter)
        {
            this.timer.skip ();
        }

        private void activate_rewind (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            // TODO: take microseconds from param

            this.timer.rewind (Pomodoro.Interval.MINUTE);
        }

        public override void dispose ()
        {
            this.timer.disconnect (timer_state_changed_id);

            base.dispose ();
        }
    }
}
