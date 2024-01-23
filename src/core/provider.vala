namespace Pomodoro
{
    public enum ProviderPriority
    {
        LOW = 0,
        DEFAULT = 1,
        HIGH = 2
    }


    /**
     * Provider class offer an integration with a specific service.
     *
     * It has many similarities with the `Capability` class, as it also needs to be initialized, enabled, disabled...
     * However, capabilities focus on specific features. Providers are meant to be lower-level and integrate with
     * external APIs or services. For instance a screen-saver, integration may be used by several capabilities;
     * if the screen-saver has several backend implementations consider implementing a provider.
     */
    public abstract class Provider : GLib.Object
    {
        public bool available {
            get;
            protected set;
            default = false;
        }

        public abstract async void initialize () throws GLib.Error;

        public abstract async void enable () throws GLib.Error;

        public abstract async void disable () throws GLib.Error;

        public abstract async void destroy () throws GLib.Error;
    }


    public abstract class ProvidedObject<T> : GLib.Object
    {
        public bool available {
            get {
                return this._provider != null;
            }
        }

        public unowned T provider {
            get {
                return this._provider;
            }
        }

        private Pomodoro.ProviderSet<T> providers = null;
        private T                       _provider = null;

        construct
        {
            this.providers = new Pomodoro.ProviderSet<T> ();
            this.providers.notify["enabled-provider"].connect (this.on_notify_enabled_provider);

            this.initialize (this.providers);

            this.providers.mark_initialized ();

            this.update_provider ();
        }

        private void on_notify_enabled_provider (GLib.Object    object,
                                                 GLib.ParamSpec pspec)
        {
            this.update_provider ();
        }

        private void set_provider (T? provider)
        {
            var previous_provider = this._provider;

            if (this._provider != null) {
                this.provider_unset (this._provider);
            }

            this._provider = provider;

            if (provider != null) {
                this.provider_set (provider);
            }

            this.notify_property ("provider");

            if ((previous_provider == null) != (provider == null)) {
                this.notify_property ("available");
            }
        }

        private void update_provider ()
        {
            if (this._provider == this.providers.enabled_provider) {
                return;
            }

            this.set_provider (this.providers.enabled_provider);
        }

        protected abstract void initialize (Pomodoro.ProviderSet<T> providers);

        protected abstract void provider_set (T provider);

        protected abstract void provider_unset (T provider);

        public override void dispose ()
        {
            this.providers.notify["enabled-provider"].disconnect (this.on_notify_enabled_provider);

            this.set_provider (null);

            this.providers = null;

            base.dispose ();
        }
    }
}
