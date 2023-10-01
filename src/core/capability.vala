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
 *
 */

using GLib;


namespace Pomodoro
{
    public delegate void CapabilityFunc (Capability capability);


    public class Capability : GLib.InitiallyUnowned
    {
        public string name { get; set; }
        public bool enabled { get; private set; }
        public unowned Pomodoro.CapabilityGroup group { get; set; }

        private Pomodoro.CapabilityFunc enable_func;
        private Pomodoro.CapabilityFunc disable_func;

        public Capability (string                   name,
                           owned Pomodoro.CapabilityFunc? enable_func  = null,
                           owned Pomodoro.CapabilityFunc? disable_func = null)
        {
            this.name = name;
            this.enable_func = (owned) enable_func;
            this.disable_func = (owned) disable_func;
        }

        [Signal (run = "first")]
        // [HasEmitter]  TODO: looks like emitters need to be written in C
        public virtual signal void enable ()
        {
            if (!this.enabled) {
                GLib.debug ("Enable capability %s.%s",
                            this.group != null ? this.group.name : "unknown",
                            this.name);

                if (this.enable_func != null) {
                    this.enable_func (this);
                }

                this.enabled = true;
            }
        }

        [Signal (run = "last")]
        // [HasEmitter]  TODO: looks like emitters need to be written in C
        public virtual signal void disable ()
        {
            if (this.enabled) {
                GLib.debug ("Disable capability %s.%s",
                            this.group != null ? this.group.name : "unknown",
                            this.name);

                if (this.disable_func != null) {
                    this.disable_func (this);
                }

                this.enabled = false;
            }
        }

        public override void dispose ()
        {
            if (this.enabled) {
                this.disable ();
            }

            base.dispose ();
        }
    }
}
