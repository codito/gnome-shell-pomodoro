using GLib;


namespace Pomodoro
{
    public class CapabilitySet : GLib.Object
    {
        [CCode (notify = false)]
        public bool enable {
            get {
                return this._enable;
            }
            set {
                if (this._enable == value) {
                    return;
                }

                this._enable = value;

                if (this._preferred_capability != null && this._preferred_capability.is_available ())
                {
                    if (this._enable) {
                        this._preferred_capability.enable ();
                    }
                    else {
                        this._preferred_capability.disable ();
                    }
                }

                this.notify_property ("enable");
            }
        }

        [CCode (notify = false)]
        public unowned Pomodoro.Capability? preferred_capability {
            get {
                return this._preferred_capability;
            }
            private set {
                if (this._preferred_capability != value)
                {
                    if (this._preferred_capability != null && (
                        this._preferred_capability.status == Pomodoro.CapabilityStatus.ENABLING ||
                        this._preferred_capability.status == Pomodoro.CapabilityStatus.ENABLED))
                    {
                        this._preferred_capability.disable ();
                    }

                    this._preferred_capability = value;

                    this.notify_property ("preferred-capability");
                }

                if (this._preferred_capability != null)
                {
                    if (!this._preferred_capability.is_initialized ()) {
                        this._preferred_capability.initialize ();
                    }

                    if (this._enable && this._preferred_capability.is_available ()) {
                        this._preferred_capability.enable ();
                    }
                }
            }
        }

        private bool                                 _enable = false;
        private Pomodoro.Capability?                 _preferred_capability = null;
        private GLib.GenericSet<Pomodoro.Capability> capabilities = null;

        public CapabilitySet ()
        {
            this.capabilities = new GLib.GenericSet<Pomodoro.Capability> (direct_hash, direct_equal);
        }

        private static int compare (Pomodoro.Capability capability,
                                    Pomodoro.Capability other)
        {
            var priority = capability.priority;
            var other_priority = other.priority;
            var is_available = capability.is_available ();
            var other_is_available = other.is_available ();

            if (is_available != other_is_available) {
                return is_available ? -1 : 1;
            }

            if (priority != other_priority) {
                return priority > other_priority ? -1 : 1;
            }

            return 0;
        }

        private void update_preferred_capability ()
        {
            unowned Pomodoro.Capability? preferred_capability = null;

            this.capabilities.@foreach (
                (capability) => {
                    if (preferred_capability == null) {
                        preferred_capability = capability;
                        return;
                    }

                    var comparison_result = compare (preferred_capability, capability);

                    if (comparison_result > 0) {
                        preferred_capability = capability;
                    }
                    else if (comparison_result == 0 && capability == this._preferred_capability) {
                        preferred_capability = capability;
                    }
                });

            this.preferred_capability = preferred_capability;
        }

        private void on_capability_notify_status (GLib.Object    object,
                                                  GLib.ParamSpec pspec)
        {
            if (object == this._preferred_capability) {
                this.status_changed (this._preferred_capability);
            }

            this.update_preferred_capability ();
        }

        public void add (Pomodoro.Capability capability)
        {
            this.capabilities.add (capability);

            if (!capability.is_initialized ()) {
                capability.initialize ();
            }

            this.update_preferred_capability ();

            capability.notify["status"].connect (this.on_capability_notify_status);
        }

        public void remove (Pomodoro.Capability capability)
        {
            this.capabilities.remove (capability);

            capability.notify["status"].disconnect (this.on_capability_notify_status);

            this.update_preferred_capability ();

            if (capability.is_initialized ()) {
                capability.uninitialize ();
            }
        }

        public bool contains (Pomodoro.Capability capability)
        {
            return this.capabilities.contains (capability);
        }

        /**
         * `status-changed` signal only tracks a preferred capability.
         */
        public signal void status_changed (Pomodoro.Capability capability);

        public override void dispose ()
        {
            if (this._preferred_capability != null && this._preferred_capability.status == Pomodoro.CapabilityStatus.ENABLED) {
                this._preferred_capability.disable ();
            }

            this.capabilities.@foreach (
                (capability) => {
                    capability.notify["status"].disconnect (this.on_capability_notify_status);
                    capability.destroy ();
                });
            this.capabilities.remove_all ();

            this._preferred_capability = null;
            this.capabilities = null;

            base.dispose ();
        }
    }
}
