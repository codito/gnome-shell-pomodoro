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
    public class TimerActionGroup : GLib.SimpleActionGroup
    {
        public Pomodoro.Timer timer { get; construct set; }

        private GLib.SimpleAction start_action;
        private GLib.SimpleAction stop_action;
        private GLib.SimpleAction pause_action;
        private GLib.SimpleAction resume_action;
        private GLib.SimpleAction skip_action;
        private GLib.SimpleAction state_action;
        private GLib.SimpleAction skip_action;
        private GLib.SimpleAction rewind_action;

        public TimerActionGroup (Pomodoro.Timer timer)
        {
            this.timer = timer;

            this.start_action = new GLib.SimpleAction ("start", null);
            this.start_action.activate.connect (this.activate_start);
            this.add_action (this.start_action);

            this.stop_action = new GLib.SimpleAction ("stop", null);
            this.stop_action.activate.connect (this.activate_stop);
            this.add_action (this.stop_action);

            this.pause_action = new GLib.SimpleAction ("pause", null);
            this.pause_action.activate.connect (this.activate_pause);
            this.add_action (this.pause_action);

            this.resume_action = new GLib.SimpleAction ("resume", null);
            this.resume_action.activate.connect (this.activate_resume);
            this.add_action (this.resume_action);

            // this.state_action = new GLib.SimpleAction.stateful ("state",
            //                                                     GLib.VariantType.STRING,
            //                                                     new GLib.Variant.string (this.timer.state.to_string ()));
            // this.state_action.activate.connect (this.activate_state);
            // this.add_action (this.state_action);

            this.skip_action = new GLib.SimpleAction ("skip", null);
            this.skip_action.activate.connect (this.activate_skip);
            this.add_action (this.skip_action);

            this.rewind_action = new GLib.SimpleAction ("rewind", null);
            this.rewind_action.activate.connect (this.activate_rewind);
            this.add_action (this.rewind_action);

            this.timer.state_changed.connect (this.on_timer_changed);
            // this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);

            this.update_action_states ();
        }

        private void update_action_states ()
        {
            var is_stopped = this.timer.is_stopped ();
            var is_paused = this.timer.is_paused ();

            this.start_action.set_enabled (is_stopped);
            this.stop_action.set_enabled (!is_stopped);
            this.pause_action.set_enabled (!is_stopped && !is_paused);
            this.resume_action.set_enabled (!is_stopped && is_paused);
            this.skip_action.set_enabled (!is_stopped);
            this.rewind_action.set_enabled (!is_stopped);
            // this.state_action.set_state (new GLib.Variant.string (this.timer.state.to_string ()));
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

        private void activate_stop (GLib.SimpleAction action,
                                    GLib.Variant?     parameter)
        {
            this.timer.stop ();
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

            this.timer.rewind (60 * 1000000);
        }

        // private void activate_state (GLib.SimpleAction action,
        //                              GLib.Variant?     parameter)
        // {
        //     this.timer.set_state (
        //         Pomodoro.State.from_string (parameter.get_string ())
        //     );
        // }
    }
}
