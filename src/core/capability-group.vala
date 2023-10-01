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
    public class CapabilityGroup : GLib.Object
    {
        public string name { get; construct set; }

        private GLib.HashTable<string,Pomodoro.Capability> capabilities;

        public CapabilityGroup (string? name = null)
        {
            this.name = name;
        }

        construct
        {
            this.capabilities = new GLib.HashTable<string, Pomodoro.Capability> (str_hash, str_equal);
        }

        public bool contains (string capability_name)
        {
            return this.capabilities.contains (capability_name);
        }

        public unowned Pomodoro.Capability lookup (string capability_name)
        {
            return this.capabilities.lookup (capability_name) as Pomodoro.Capability;
        }

        public void @foreach (GLib.HFunc<string, Pomodoro.Capability> func)
        {
            this.capabilities.@foreach (func);
        }

        public bool add (Pomodoro.Capability capability)
        {
            var existing_capability = this.capabilities.lookup (capability.name);

            if (existing_capability != null) {
                return false;
            }

            this.capabilities.insert (capability.name, capability);

            capability.group = this;

            this.capability_added (capability);

            return true;
        }

        public void replace (Pomodoro.Capability capability)
        {
            var existing_capability = this.capabilities.lookup (capability.name);

            if (existing_capability == capability) {
                return;
            }

            if (existing_capability == null) {
                this.capabilities.insert (capability.name, capability);
            }
            else {
                this.capabilities.replace (capability.name, capability);

                this.capability_removed (existing_capability);
            }

            capability.group = this;

            this.capability_added (capability);
        }

        public void remove (string capability_name)
        {
            var capability = this.lookup (capability_name);

            if (capability != null) {
                this.capabilities.remove (capability_name);

                // Group would be overriden when adding same capability to a group again
                // if (capability.group == this) {
                //     capability.group = null;
                // }

                this.capability_removed (capability);
            }
        }

        public void remove_all ()
        {
            foreach (var capability_name in this.capabilities.get_keys ()) {
                this.remove (capability_name);
            }
        }

        public signal void capability_added (Pomodoro.Capability capability);

        public signal void capability_removed (Pomodoro.Capability capability);
    }
}
