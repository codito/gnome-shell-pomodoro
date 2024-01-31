/*
 * Copyright (c) 2016,2024 gnome-pomodoro contributors
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
    public delegate void CapabilityStatusChangedFunc (Pomodoro.Capability capability);


    internal struct CapabilityMeta
    {
        public string            name;
        public Pomodoro.Priority priority;
        public GLib.Type         class_type;
    }


    [SingleInstance]
    public class CapabilityManager : GLib.Object
    {
        private GLib.HashTable<string, Pomodoro.CapabilitySet> capabilities;
        private bool                                           destroying = false;

        private static Pomodoro.CapabilityMeta[] registry;

        construct
        {
            this.capabilities = new GLib.HashTable<string, Pomodoro.CapabilitySet> (str_hash, str_equal);
        }

        public void populate ()
        {
            for (var index = 0; index < registry.length; index++)
            {
                var capability_meta = registry[index];

                var name_value = GLib.Value (typeof (string));
                name_value.set_string (capability_meta.name);

                var priority_value = GLib.Value (typeof (Pomodoro.Priority));
                priority_value.set_enum (capability_meta.priority);

                this.register ((Pomodoro.Capability) GLib.Object.new_with_properties (capability_meta.class_type,
                                                                                      {"name", "priority"},
                                                                                      {name_value, priority_value}));
            }
        }

        /**
         * Return a preferred capability.
         */
        public unowned Pomodoro.Capability? lookup (string capability_name)
        {
            var capability_set = this.capabilities.lookup (capability_name);

            return capability_set != null
                ? capability_set.preferred_capability
                : null;
        }

        public bool is_available (string capability_name)
        {
            var capability = this.capabilities.lookup (capability_name)?.preferred_capability;

            return capability != null
                ? capability.is_available ()
                : false;
        }

        public bool is_enabled (string capability_name)
        {
            var capability = this.capabilities.lookup (capability_name)?.preferred_capability;

            return capability != null
                ? capability.is_enabled ()
                : false;
        }

        public static void register_class (string            name,
                                           Pomodoro.Priority priority,
                                           GLib.Type         class_type)
        {
            registry += Pomodoro.CapabilityMeta () {
                name = name,
                priority = priority,
                class_type = class_type
            };
        }

        public void register (Pomodoro.Capability capability)
                              requires (capability.name != null)
        {
            var capability_set = this.ensure_capability_set (capability.name);

            if (!capability_set.contains (capability)) {
                capability_set.add (capability);
            }
        }

        public void unregister (Pomodoro.Capability capability)
        {
            var capability_name = capability.name;
            var capability_set = this.capabilities.lookup (capability_name);

            if (capability_set != null) {
                capability_set.remove (capability);
            }
        }

        private unowned Pomodoro.CapabilitySet ensure_capability_set (string capability_name)
        {
            unowned Pomodoro.CapabilitySet existing_capability_set = this.capabilities.lookup (capability_name);

            if (existing_capability_set == null)
            {
                var capability_set = new Pomodoro.CapabilitySet ();

                this.capabilities.insert (capability_name, capability_set);

                capability_set.status_changed.connect (
                    (capability) => {
                        this.status_changed (capability);
                    });

                existing_capability_set = capability_set;
            }

            return existing_capability_set;
        }

        /**
         * Mark capability to be enabled.
         */
        public void enable (string capability_name)
                            requires (!this.destroying)
        {
            var capability_set = this.ensure_capability_set (capability_name);

            capability_set.enable = true;
        }

        public void disable (string capability_name)
                             requires (!this.destroying)
        {
            var capability_set = this.capabilities.lookup (capability_name);

            if (capability_set != null) {
                capability_set.enable = false;
            }
        }

        public void activate (string capability_name)
                              requires (!this.destroying)
       {
            var capability = this.lookup (capability_name);

            if (capability == null) {
                GLib.debug ("Can't activate capability %s: it doesn't exist.", capability_name);
                return;
            }

            if (capability.status != Pomodoro.CapabilityStatus.ENABLED) {
                GLib.debug ("Can't activate capability %s: its status is \"%s\"",
                            capability.get_debug_name (),
                            capability.status.to_string ());
                return;
            }

            capability.activate ();
        }

        public ulong add_watch (string                               capability_name,
                                Pomodoro.CapabilityStatusChangedFunc status_changed_func)
        {
            var capability_set = this.ensure_capability_set (capability_name);

            return capability_set.status_changed.connect (
                (capability) => {
                    status_changed_func (capability);
                });
        }

        public void remove_watch (string capability_name,
                                  ulong  handler_id)
        {
            var capability_set = this.capabilities.lookup (capability_name);

            if (capability_set == null) {
                return;
            }

            capability_set.disconnect (handler_id);
        }

        /**
         * `status-changed` signal only track of a preferred capabilities, so that you don't get updated about
         * capabilities that may be asynchronously disabled.
         */
        public signal void status_changed (Pomodoro.Capability capability);

        public void destroy ()
        {
            this.destroying = true;

            this.capabilities.foreach_remove (
                (capability_name, capability_set) => {
                    capability_set.enable = false;

                    return true;
                });
        }

        public override void dispose ()
        {
            if (!this.destroying) {
                this.destroy ();
            }

            this.capabilities = null;

            base.dispose ();
        }
    }
}
