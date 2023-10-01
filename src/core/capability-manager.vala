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
    public enum Priority
    {
        LOW = 0,
        DEFAULT = 1,
        HIGH = 2
    }

    public class CapabilityManager : GLib.Object
    {
        private GLib.HashTable<string,Pomodoro.Capability> capabilities;
        private GLib.GenericSet<string>                    enabled_capabilities;
        private GLib.SList<Pomodoro.CapabilityGroup>       groups;

        construct
        {
            /* all collected capabilities except overriden ones */
            this.capabilities = new GLib.HashTable<string, Pomodoro.Capability> (str_hash, str_equal);

            /* keep capability "enabled" status regardless of implementation or timing */
            this.enabled_capabilities = new GLib.GenericSet<string> (str_hash, str_equal);

            /* list of groups sorted by priority */
            this.groups = new GLib.SList<Pomodoro.CapabilityGroup> ();
        }

        public unowned Pomodoro.Capability get_preferred_capability (string capability_name)
        {
            return this.capabilities.lookup (capability_name);
        }

        public bool has_capability (string capability_name)
        {
            return this.capabilities.contains (capability_name);
        }

        public bool has_enabled (string capability_name)
        {
            var capability = this.capabilities.lookup (capability_name);

            return capability != null ? capability.enabled : false;
        }

        public bool has_group (Pomodoro.CapabilityGroup group)
        {
            return this.groups.index (group) >= 0;
        }

        public void add_group (Pomodoro.CapabilityGroup group,
                               Pomodoro.Priority        priority)
        {
            unowned GLib.SList<Pomodoro.CapabilityGroup> group_link = this.groups.find (group);

            if (group_link == null) {
                set_group_priority (group, priority);

                this.groups.insert_sorted (group, group_priority_compare);

                group.capability_added.connect (this.on_group_capability_added);
                group.capability_removed.connect (this.on_group_capability_removed);

                group.foreach ((capability_name, capability) => {
                    this.add_capability_internal (capability);
                });

                this.group_added (group);
            }
            else {
                // TODO: change group priority
            }
        }

        public void remove_group (Pomodoro.CapabilityGroup group)
        {
            unowned GLib.SList<Pomodoro.CapabilityGroup> group_link = this.groups.find (group);

            if (group_link != null)
            {
                this.groups.remove_link (group_link);

                group.capability_added.disconnect (this.on_group_capability_added);
                group.capability_removed.disconnect (this.on_group_capability_removed);

                group.foreach ((capability_name, capability) => {
                    this.remove_capability_internal (capability);
                });

                this.group_removed (group);
            }
        }

        public void enable (string capability_name)
        {
            var capability = capabilities.lookup (capability_name);

            this.enabled_capabilities.add (capability_name);

            if (capability != null && !capability.enabled) {
                capability.enable ();
            }
        }

        public void disable (string capability_name)
        {
            var capability = capabilities.lookup (capability_name);

            this.enabled_capabilities.remove (capability_name);

            if (capability != null && capability.enabled) {
                capability.disable ();
            }
        }

        public void disable_all ()
        {
            this.enabled_capabilities.foreach ((capability_name) => {
                var capability = capabilities.lookup (capability_name);

                if (capability != null && capability.enabled) {
                    capability.disable ();
                }
            });

            this.enabled_capabilities.remove_all ();
        }

        private static Pomodoro.Priority get_group_priority (Pomodoro.CapabilityGroup group)
        {
            return group.get_data<Pomodoro.Priority> ("priority");
        }

        private static void set_group_priority (Pomodoro.CapabilityGroup group,
                                                Pomodoro.Priority        priority)
        {
            group.set_data<Pomodoro.Priority> ("priority", priority);
        }

        [CCode (has_target = false)]
        private static int group_priority_compare (Pomodoro.CapabilityGroup a,
                                                   Pomodoro.CapabilityGroup b)
        {
            var a_priority = get_group_priority (a);
            var b_priority = get_group_priority (b);

            if (a_priority > b_priority) {
                return -1;
            }

            if (a_priority < b_priority) {
                return 1;
            }

            return 0;
        }

        private void add_capability_internal (Pomodoro.Capability capability)
        {
            var preferred_capability = this.capabilities.lookup (capability.name);

            if (preferred_capability != null) {
                preferred_capability.disable ();

                if (get_group_priority (preferred_capability.group) <
                    get_group_priority (capability.group))
                {
                    this.capabilities.replace (capability.name, capability);
                }
            }
            else {
                this.capabilities.insert (capability.name, capability);
            }

            if (this.enabled_capabilities.contains (capability.name)) {
                if (!capability.enabled) {
                    capability.enable ();
                }

                this.capability_enabled (capability.name);
            }
            else {
                if (capability.enabled) {
                    capability.disable ();
                }
            }
        }

        private void remove_capability_internal (Pomodoro.Capability capability)
        {
            var preferred_capability = this.capabilities.lookup (capability.name);

            if (preferred_capability == capability)
            {
                this.capabilities.remove (capability.name);

                capability.disable ();

                /* select new preferred implementation */

                unowned GLib.SList<Pomodoro.CapabilityGroup> iter = this.groups;

                while (iter != null)
                {
                    preferred_capability = iter.data.lookup (capability.name);

                    if (preferred_capability != null) {
                        this.add_capability_internal (preferred_capability);
                        break;
                    }

                    iter = iter.next;
                }

                this.capability_disabled (capability.name);
            }
        }

        private void on_group_capability_added (Pomodoro.CapabilityGroup group,
                                                Pomodoro.Capability      capability)
        {
            this.add_capability_internal (capability);
        }

        private void on_group_capability_removed (Pomodoro.CapabilityGroup group,
                                                  Pomodoro.Capability      capability)
        {
            this.remove_capability_internal (capability);
        }

        public override void dispose ()
        {
            this.disable_all ();

            base.dispose ();
        }

        public signal void group_added (Pomodoro.CapabilityGroup group);

        public signal void group_removed (Pomodoro.CapabilityGroup group);

        public signal void capability_enabled (string capability_name);

        public signal void capability_disabled (string capability_name);
    }
}
