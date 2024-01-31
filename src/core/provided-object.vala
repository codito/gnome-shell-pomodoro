namespace Pomodoro
{
    public abstract class ProvidedObject<T> : GLib.Object
    {
        [CCode (notify = false)]
        public bool available {
            get {
                return _available;
            }
            private set {
                if (this._available != value)
                {
                    this._available = value;
                    this.notify_property ("available");
                }
            }
        }

        [CCode (notify = false)]
        public bool enabled {
            get {
                return _enabled;
            }
            private set {
                if (this._enabled != value)
                {
                    this._enabled = value;
                    this.notify_property ("enabled");
                }
            }
        }

        /**
         * A selected provider. It may not be available nor enabled.
         */
        [CCode (notify = false)]
        public unowned T provider {
            get {
                return (T) this._provider;
            }
            private set {
                var provider = value as Pomodoro.Provider;

                if (this._provider != provider)
                {
                    this._provider = provider;
                    this.notify_property ("provider");

                    this.available = provider != null ? provider.available : false;
                    this.enabled = provider != null ? provider.enabled : false;
                }
            }
        }

        protected Pomodoro.ProviderSet<T> providers = null;

        private Pomodoro.Provider       _provider = null;
        private bool                    _available = false;
        private bool                    _enabled = false;
        // private ulong                   provider_initialized_id = 0;
        // private ulong                   provider_uninitialized_id = 0;
        private ulong                   provider_selected_id = 0;
        private ulong                   provider_unselected_id = 0;
        private ulong                   provider_enabled_id = 0;
        private ulong                   provider_disabled_id = 0;


        construct
        {
            this.providers = new Pomodoro.ProviderSet<Pomodoro.Provider> ();
            this.provider_selected_id = this.providers.provider_selected.connect (this.on_provider_selected);
            this.provider_unselected_id = this.providers.provider_unselected.connect (this.on_provider_unselected);
            // this.provider_initialized_id = this.providers.provider_initialized.connect (this.on_provider_initialized);
            // this.provider_uninitialized_id = this.providers.provider_uninitialized.connect (this.on_provider_uninitialized);
            this.provider_enabled_id = this.providers.provider_enabled.connect (this.on_provider_enabled);
            this.provider_disabled_id = this.providers.provider_disabled.connect (this.on_provider_disabled);

            this.setup_providers ();

            this.providers.enable_one ();
        }

        private void on_provider_notify_available (GLib.Object    object,
                                                   GLib.ParamSpec pspec)

        {
            var _provider = (Pomodoro.Provider) provider;

            if (this._provider == _provider) {
                this.available = _provider.available;
            }
        }

        private void on_provider_selected (T provider)
        {
            var _provider = (Pomodoro.Provider) provider;
            _provider.notify["available"].connect (this.on_provider_notify_available);

            this.provider = _provider;
        }

        private void on_provider_unselected (T provider)
        {
            var _provider = (Pomodoro.Provider) provider;
            _provider.notify["available"].disconnect (this.on_provider_notify_available);

            if (this._provider == _provider) {
                this.provider = null;
            }
        }

        private void on_provider_enabled (T provider)
        {
            if (this._provider == provider) {
                this.enabled = true;
            }

            this.provider_enabled (provider);
        }

        private void on_provider_disabled (T provider)
        {
            if (this._provider == provider) {
                this.enabled = false;
            }

            this.provider_disabled (provider);
        }

        protected abstract void setup_providers ();

        protected abstract void provider_enabled (T provider);

        protected abstract void provider_disabled (T provider);

        public override void dispose ()
        {
            if (this._provider != null) {
                ((GLib.Object) this._provider).notify["available"].disconnect (this.on_provider_notify_available);
            }

            if (this.provider_selected_id != 0) {
                this.providers.disconnect (this.provider_selected_id);
                this.provider_selected_id = 0;
            }

            if (this.provider_unselected_id != 0) {
                this.providers.disconnect (this.provider_unselected_id);
                this.provider_unselected_id = 0;
            }

            this._provider = null;
            this.providers = null;

            // if (this.provider_initialized_id != 0) {
            //     this.providers.disconnect (this.provider_initialized_id);
            //     this.provider_initialized_id = 0;
            // }

            // if (this.provider_uninitialized_id != 0) {
            //     this.providers.disconnect (this.provider_uninitialized_id);
            //     this.provider_uninitialized_id = 0;
            // }

            // if (this.provider_enabled_id != 0) {
            //     this.providers.disconnect (this.provider_enabled_id);
            //     this.provider_enabled_id = 0;
            // }

            // if (this.provider_disabled_id != 0) {
            //     this.providers.disconnect (this.provider_disabled_id);
            //     this.provider_disabled_id = 0;
            // }

            base.dispose ();
        }
    }
}
