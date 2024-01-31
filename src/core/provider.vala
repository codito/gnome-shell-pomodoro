namespace Pomodoro
{
    /**
     * Provider class helps integrating with an external service. Unlike capabilities which may be enabled/disabled
     * according to settings, providers are enabled according to use. Another difference: for a capability
     * enable/disable operations should be trivial and always be successful, for providers it needs error handling.
     *
     * Subclass should contain implementation. To use it look at `ProviderSet`.
     */
    public abstract class Provider : GLib.Object
    {
        [CCode (notify = false)]
        public bool available {
            get {
                return this._available;
            }
            set {
                if (this._available != value || !this._available_set)
                {
                    var available_set_changed = !this._available_set;

                    this._available = value;
                    this._available_set = true;

                    this.notify_property ("available");

                    if (available_set_changed) {
                        this.notify_property ("available-set");
                    }
                }
            }
        }

        public bool available_set {
            get {
                return this._available_set;
            }
        }

        [CCode (notify = false)]
        public bool enabled {
            get {
                return this._enabled;
            }
            internal set {
                if (this._enabled != value)
                {
                    this._enabled = value;
                    this.notify_property ("enabled");
                }
            }
        }

        private bool _available = false;
        private bool _available_set = false;
        private bool _enabled = false;

        /**
         * Set-up detection whether provider is available. Once available, the provider should set
         * the `available` property accordingly.
         *
         * If error happens during initialization, it's considered as uninitialized.
         */
        public abstract async void initialize (GLib.Cancellable? cancellable) throws GLib.Error;

        /**
         * Undo the effects of `initialize`
         *
         * If error happens during uninitialization, it's still considered as uninitialized.
         */
        public abstract async void uninitialize () throws GLib.Error;

        /**
         * Enable the provider.
         *
         * If error happens during enabling, it's considered as disabled.
         */
        public abstract async void enable (GLib.Cancellable? cancellable) throws GLib.Error;

        /**
         * Undo the effects of `enable`.
         *
         * It may be called despite provider being unavailable.
         *
         * If error happens during disabling, it's considered as initialized; therefore
         * the provider should mark any registered callbacks as invalid in its internal state.
         */
        public abstract async void disable () throws GLib.Error;
    }
}
