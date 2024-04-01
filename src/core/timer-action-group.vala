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
        public Pomodoro.Timer timer { get; construct; }

        public TimerActionGroup ()
        {
            GLib.Object (
                timer: Pomodoro.Timer.get_default ()
            );
        }

        construct
        {
            var start_action = new GLib.SimpleAction ("start", null);
            start_action.activate.connect (this.activate_start);
            this.add_action (start_action);

            var reset_action = new GLib.SimpleAction ("reset", null);
            reset_action.activate.connect (this.activate_reset);
            this.add_action (reset_action);

            var pause_action = new GLib.SimpleAction ("pause", null);
            pause_action.activate.connect (this.activate_pause);
            this.add_action (pause_action);

            var resume_action = new GLib.SimpleAction ("resume", null);
            resume_action.activate.connect (this.activate_resume);
            this.add_action (resume_action);

            var rewind_action = new GLib.SimpleAction ("rewind", null);
            rewind_action.activate.connect (this.activate_rewind);
            this.add_action (rewind_action);
        }

        private void activate_start (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("timer.start");
            this.timer.start ();
        }

        private void activate_reset (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("timer.reset");
            this.timer.reset ();
        }

        private void activate_pause (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("timer.pause");
            this.timer.pause ();
        }

        private void activate_resume (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            Pomodoro.Context.set_event_source ("timer.resume");
            this.timer.resume ();
        }

        private void activate_rewind (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            // TODO: take microseconds from param

            Pomodoro.Context.set_event_source ("timer.rewind");
            this.timer.rewind (Pomodoro.Interval.MINUTE);
        }
    }
}
