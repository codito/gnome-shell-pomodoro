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
    public enum CapabilityStatus
    {
        NULL,
        UNAVAILABLE,
        DISABLED,
        DISABLING,
        ENABLED,
        ENABLING;

        public string to_string ()
        {
            switch (this)
            {
                case NULL:
                    return "null";

                case UNAVAILABLE:
                    return "unavailable";

                case DISABLED:
                    return "disabled";

                case DISABLING:
                    return "disabling";

                case ENABLED:
                    return "enabled";

                case ENABLING:
                    return "enabling";

                default:
                    assert_not_reached ();
           }
        }

        /**
         * The intent of a validation is to log a warning about possible error or inconsistency.
         *
         * UNAVAILABLE status may be error prone. We assume that capability may become unavailable at any point.
         * Once it becomes available it jumps back to ENABLED or DISABLED status.
         */
        public bool validate_transition (Pomodoro.CapabilityStatus target_status)
        {
            if (target_status == this) {
                return true;
            }

            switch (target_status)
            {
                case NULL:
                    return this == DISABLED || this == UNAVAILABLE;

                case UNAVAILABLE:
                    return true;

                case DISABLED:
                    return this == NULL || this == DISABLING || this == ENABLED || this == UNAVAILABLE;

                case DISABLING:
                    return this == ENABLED;

                case ENABLING:
                    return this == DISABLED;

                case ENABLED:
                    return this == ENABLING || this == DISABLED || this == UNAVAILABLE;

                default:
                    assert_not_reached ();
            }
        }
    }


    /**
     * A capability is a feature that is optional and contains a single implementation. Alternative implementations
     * (eg for GNOME or Freedesktop) should be implemented as separate capabilities and registered with different
     * priorities.
     */
    public abstract class Capability : GLib.InitiallyUnowned
    {
        public string name {
            get;
            construct;
        }

        public Pomodoro.Priority priority {
            get;
            construct;
            default = Pomodoro.Priority.DEFAULT;
        }

        [CCode (notify = false)]
        public Pomodoro.CapabilityStatus status {
            get {
                return this._status;
            }
            protected set {
                if (this._status == value) {
                    return;
                }

                if (!this._status.validate_transition (value)) {
                     GLib.warning ("Invalid status transition of capability %s from %s to %s.",
                                   this.get_debug_name (),
                                   this._status.to_string (),
                                   value.to_string ());
                }

                this._status = value;

                this.notify_property ("status");
            }
        }

        private Pomodoro.CapabilityStatus _status = Pomodoro.CapabilityStatus.NULL;
        private GLib.GenericSet<string>?  details = null;

        protected Capability (string            name,
                              Pomodoro.Priority priority = Pomodoro.Priority.DEFAULT)
        {
            GLib.Object (
                name: name,
                priority: priority
            );
        }

        public inline string get_debug_name ()
        {
            return this.name != null
                ? @"$(this.name) ($(this.get_type ().name ()))"
                : @"$(this.get_type ().name ())";
        }

        public inline bool is_initialized ()
        {
            return this.status != Pomodoro.CapabilityStatus.NULL;
        }

        public inline bool is_available ()
        {
            return this.status != Pomodoro.CapabilityStatus.NULL &&
                   this.status != Pomodoro.CapabilityStatus.UNAVAILABLE;
        }

        public inline bool is_enabled ()
        {
            return this.status == Pomodoro.CapabilityStatus.ENABLED;
        }

        public void add_detail (string detail)
        {
            if (this.details == null) {
                this.details = new GLib.GenericSet<string> (str_hash, str_equal);
            }

            this.details.add (detail);
        }

        public void remove_detail (string detail)
        {
            if (this.details != null) {
                this.details.remove (detail);
            }
        }

        public void remove_all_details ()
        {
            this.details = null;
        }

        public bool has_detail (string detail)
        {
            return this.details != null && this.details.contains (detail);
        }

        /**
         * Check if capability is available / can be enabled.
         *
         * When successful, the capability should change its state from NULL to DISABLED.
         * If the capability is can become unavailable, the initialization should set up a watch and transition to
         * UNAVAILABLE status from any status.
         */
        public virtual void initialize ()
        {
            this.status = Pomodoro.CapabilityStatus.DISABLED;
        }

        public virtual void uninitialize ()
        {
            this.status = Pomodoro.CapabilityStatus.NULL;

            this.remove_all_details ();
        }

        /**
         * Enable capability.
         *
         * It's expected to be a trivial operation. A timeout or an error should be logged, and capability should
         * transition to ENABLED status anyway.
         */
        public virtual void enable ()
        {
            assert (this.is_available ());

            this.status = Pomodoro.CapabilityStatus.ENABLED;
        }

        /**
         * Disable capability.
         */
        public virtual void disable ()
        {
            this.status = Pomodoro.CapabilityStatus.DISABLED;
        }

        /**
         * Activate a default action, it one exists.
         *
         * You should override it without calling base method.
         */
        public virtual void activate ()
        {
            assert (this.is_available ());

            GLib.debug ("Unhandled capability %s activation.", this.get_debug_name ());
        }

        public void destroy ()
                             ensures (this.status == Pomodoro.CapabilityStatus.NULL)
        {
            if (this.status == Pomodoro.CapabilityStatus.ENABLED) {
                this.disable ();
            }

            if (this.status == Pomodoro.CapabilityStatus.DISABLED ||
                this.status == Pomodoro.CapabilityStatus.UNAVAILABLE)
            {
                this.uninitialize ();
            }
        }

        public override void dispose ()
        {
            this.destroy ();

            base.dispose ();
        }
    }


    /*
    public class SimpleCapability : Pomodoro.Capability
    {
        private GLib.Callback? enable_func = null;
        private GLib.Callback? disable_func = null;
        private GLib.Callback? activate_func = null;

        public SimpleCapability (string               name,
                                 Pomodoro.Priority    priortity,
                                 owned GLib.Callback? enable_func,
                                 owned GLib.Callback? disable_func,
                                 owned GLib.Callback? activate_func = null)
                                 requires ((enable_func == null) == (disable_func == null))
        {
            base (name);

            this.enable_func = (owned) enable_func;
            this.disable_func = (owned) disable_func;
            this.activate_func = (owned) activate_func;
        }

        public override void enable ()
        {
            if (this.status == Pomodoro.CapabilityStatus.ENABLING ||
                this.status == Pomodoro.CapabilityStatus.ENABLED)
            {
                GLib.warning ("Capability %s is already enabled.", this.get_debug_name ());
                return;
            }

            if (this.status != Pomodoro.CapabilityStatus.DISABLED) {
                GLib.warning ("Capability %s is not available.", this.get_debug_name ());
                return;
            }

            var previous_status = this.status;

            // this.status = Pomodoro.CapabilityStatus.ENABLING;

            if (this.enable_func != null) {
                this.enable_func ();
            }

            base.enable ();
        }

        public override void disable ()
        {
            if (this.status != Pomodoro.CapabilityStatus.UNAVAILABLE) {
                GLib.warning ("Capability %s is not available.", this.get_debug_name ());
                return;
            }

            if (this.status != Pomodoro.CapabilityStatus.ENABLED) {
                GLib.warning ("Capability %s is not enabled.", this.get_debug_name ());
                return;
            }

            var previous_status = this.status;

            // this.status = Pomodoro.CapabilityStatus.DISABLING;

            if (this.disable_func != null) {
                this.disable_func ();
            }

            base.disable ();
        }

        public override void activate ()
        {
            if (this.status != Pomodoro.CapabilityStatus.ENABLED) {
                GLib.warning ("Capability %s is not enabled.", this.get_debug_name ());
                return;
            }

            if (this.activate_func != null) {
                this.activate_func (timestamp);
            }
            else {
                base.activate ();
            }
        }

        public override void dispose ()
        {
            this.enable_func = null;
            this.disable_func = null;
            this.activate_func = null;

            base.dispose ();
        }
    }
    */

    /*  TODO: move to service?
    public class ExternalCapability : Pomodoro.SimpleCapability
    {
        private static uint next_id = 1;

        public uint id {
            get {
                return this._id;
            }
            construct {
                this._id = next_id;

                next_id++;
            }
        }

        private uint _id = 0;

        public ExternalCapability (string               name,
                                   Pomodoro.Priority    priority,
                                   owned GLib.Callback? enable_func,
                                   owned GLib.Callback? disable_func,
                                   owned GLib.Callback? activate_func = null)
        {
            base (name,
                  priority,
                  (owned) enable_func,
                  (owned) disable_func,
                  (owned) activate_func);
        }
    }
    */
}
