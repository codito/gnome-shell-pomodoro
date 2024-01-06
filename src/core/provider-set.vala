namespace Pomodoro
{
    // TODO: move it into Provider, could be a simple struct
    [Compact]
    internal class ProviderMeta
    {
        public Pomodoro.ProviderPriority priority;

        public ProviderMeta (Pomodoro.ProviderPriority priority = Pomodoro.ProviderPriority.DEFAULT)
        {
            this.priority = priority;
        }
    }


    public class ProviderSet<T> : GLib.Object
    {
        [CCode (notify = false)]
        public unowned T preferred_provider {
            get {
                return (T) this._preferred_provider;
            }
        }

        [CCode (notify = false)]
        public unowned T enabled_provider {
            get {
                return (T) this._enabled_provider;
            }
        }

        private GLib.HashTable<Pomodoro.Provider, Pomodoro.ProviderMeta> providers = null;
        private unowned Pomodoro.Provider?                              _preferred_provider = null;
        private unowned Pomodoro.Provider?                              _enabling_provider = null;
        private unowned Pomodoro.Provider?                              _enabled_provider = null;
        private bool                                                    initialized = false;
        private uint                                                    idle_id = 0;

        construct
        {
            this.providers = new GLib.HashTable<Pomodoro.Provider, Pomodoro.ProviderMeta> (direct_hash, direct_equal);
            this.initialized = false;

            this.idle_id = GLib.Idle.add (
                () => {
                    this.mark_initialized ();

                    return GLib.Source.REMOVE;
                }
            );
        }

        private static int compare (Pomodoro.Provider     provider,
                                    Pomodoro.ProviderMeta provider_meta,
                                    Pomodoro.Provider     other,
                                    Pomodoro.ProviderMeta other_meta)
        {
            if (provider.available != other.available) {
                return provider.available ? -1 : 1;
            }

            if (provider_meta.priority > other_meta.priority) {
                return -1;
            }

            if (other_meta.priority > provider_meta.priority) {
                return 1;
            }

            return 0;
        }

        private void update_preferred_provider ()
        {
            unowned Pomodoro.Provider?     preferred_provider = null;
            unowned Pomodoro.ProviderMeta? preferred_provider_meta = null;

            this.providers.@foreach (
                (provider, provider_meta) => {
                    if (preferred_provider == null) {
                        preferred_provider = provider;
                        preferred_provider_meta = provider_meta;
                        return;
                    }

                    var comparison_result = compare (preferred_provider,
                                                     preferred_provider_meta,
                                                     provider,
                                                     provider_meta);
                    if ((comparison_result > 0) ||
                        (comparison_result == 0 && this._preferred_provider == provider))
                    {
                        preferred_provider = provider;
                        preferred_provider_meta = provider_meta;
                    }
                });

            if (this._preferred_provider != preferred_provider)
            {
                this._preferred_provider = preferred_provider;

                this.notify_property ("preferred-provider");
            }

            if (this.initialized) {
                this.enable_preferred_provider.begin ();
            }
        }

        private void on_provider_notify_available (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            this.update_preferred_provider ();
        }

        private void add_internal (Pomodoro.Provider           provider,
                                   owned Pomodoro.ProviderMeta provider_meta)
        {
            if (this.providers.insert (provider, (owned) provider_meta))
            {
                provider.notify["available"].connect (this.on_provider_notify_available);

                // Assume provider hasn't been initialized yet.
                provider.initialize.begin (
                    (obj, res) => {
                        try {
                            provider.initialize.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while initializing %s: %s",
                                          provider.get_type ().name (),
                                          error.message);
                        }
                    });
            }
            else {
                // Meta got replaced.

                this.update_preferred_provider ();
            }
        }

        public void add (T                         provider,
                         Pomodoro.ProviderPriority priority = Pomodoro.ProviderPriority.DEFAULT)
        {
            var instance = provider as Pomodoro.Provider;

            if (instance == null) {
                GLib.warning ("Unable to add provider to a set. Wrong type.");
                return;
            }

            this.add_internal (instance, new Pomodoro.ProviderMeta (priority));
        }

        public void remove (T provider)
        {
            var instance = provider as Pomodoro.Provider;

            if (instance == null) {
                return;
            }

            if (!this.providers.remove (instance)) {
                return;
            }

            this.destroy_provider (instance);

            if (this._preferred_provider == instance) {
                this.update_preferred_provider ();
            }
        }

        private async void enable_preferred_provider ()
                                                      requires (this.initialized)
        {
            var preferred_provider = this._preferred_provider;

            if (this._enabling_provider == preferred_provider ||
                this._enabled_provider == preferred_provider && this._enabling_provider == null)
            {
                return;
            }

            if (preferred_provider != null)
            {
                this._enabling_provider = preferred_provider;

                try {
                    yield preferred_provider.enable ();

                    if (this._enabling_provider == preferred_provider) {
                        this._enabling_provider = null;
                        this._enabled_provider = preferred_provider;
                        this.notify_property ("enabled-provider");
                    }
                }
                catch (GLib.Error error) {
                    GLib.warning ("Error while enabling provider: %s", error.message);
                    this._enabling_provider = null;
                }
            }
        }

        /**
         * Mark the end of initialization and enable a preferred provider.
         */
        public void mark_initialized ()
        {
            if (this.initialized) {
                return;
            }

            this.initialized = true;

            this.enable_preferred_provider.begin ();
        }

        private void destroy_provider (Pomodoro.Provider provider)
        {
            provider.notify["available"].disconnect (this.on_provider_notify_available);
            provider.destroy.begin ();
        }

        private void dispose_providers ()
        {
            if (this.providers != null)
            {
                this.providers.@foreach (
                    (provider, provider_meta) => {
                        this.destroy_provider (provider);
                    });
                this.providers.remove_all ();
                this.providers = null;
            }
        }

        public override void dispose ()
        {
            this._preferred_provider = null;
            this._enabling_provider = null;

            if (this._enabled_provider != null) {
                this._enabled_provider.disable.begin (
                    (obj, res) => {
                        try {
                            this._enabled_provider.disable.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.debug ("Error while disabling provider: %s", error.message);
                        }

                        this._enabled_provider = null;
                        this.dispose_providers ();
                    }
                );
            }
            else {
                this.dispose_providers ();
            }

            base.dispose ();
        }
    }
}
