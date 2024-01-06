namespace Pomodoro
{
    public delegate void BecameIdleFunc ();


    public interface IdleMonitorProvider : Pomodoro.Provider
    {
        public abstract int64 get_idle_time () throws GLib.Error;
        public abstract uint32 add_watch (int64 timeout, int64 monotonic_time) throws GLib.Error;
        public abstract void remove_watch (uint32 id) throws GLib.Error;
        public abstract uint32 reset_watch (uint32 id, int64 monotonic_time) throws GLib.Error;

        public abstract signal void became_idle (uint32 id);
        public abstract signal void became_active ();
    }


    [SingleInstance]
    public class IdleMonitor : GLib.Object
    {
        private static uint next_id = 1;

        [Compact]
        class Watch
        {
            public uint                                  id = 0;
            public uint32                                external_id = 0;
            public int64                                 timeout = 0;
            public int64                                 reference_time = Pomodoro.Timestamp.UNDEFINED;
            public Pomodoro.BecameIdleFunc               callback;
            public bool                                  invalid = false;
            public unowned Pomodoro.IdleMonitorProvider? provider = null;
        }

        public bool available {
            get {
                return this.provider != null;
            }
        }

        private Pomodoro.ProviderSet<Pomodoro.IdleMonitorProvider> providers = null;
        private Pomodoro.IdleMonitorProvider?                      provider = null;
        private GLib.HashTable<int64?, Watch>                      watches = null;

        construct
        {
            this.watches = new GLib.HashTable<int64?, Watch> (int64_hash, int64_equal);

            this.providers = new Pomodoro.ProviderSet<Pomodoro.IdleMonitorProvider> ();
            this.providers.notify["enabled-provider"].connect (this.on_notify_enabled_provider);

            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Gnome.IdleMonitorProvider (), Pomodoro.ProviderPriority.HIGH);

            this.providers.mark_initialized ();

            this.update_provider ();
        }

        private void set_provider (Pomodoro.IdleMonitorProvider? provider)
        {
            var previous_provider = this.provider;

            if (this.provider != null)
            {
                this.provider.became_idle.disconnect (this.on_became_idle);
                this.provider.became_active.disconnect (this.on_became_active);

                this.watches.@foreach (
                    (id, watch) => {
                        try {
                            this.provider.remove_watch (watch.external_id);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while removing idle watch: %s", error.message);
                        }

                        watch.external_id = 0;
                    });
            }

            this.provider = provider;

            if (provider != null)
            {
                provider.became_idle.connect (this.on_became_idle);
                provider.became_active.connect (this.on_became_active);

                // Recreate watches with the new provider.
                this.watches.@foreach (
                    (id, watch) => {
                        try {
                            watch.external_id = this.provider.add_watch (watch.timeout, watch.reference_time);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while adding idle watch: %s", error.message);
                        }
                    });
            }

            if ((previous_provider == null) != (provider == null)) {
                this.notify_property ("available");
            }
        }

        private void update_provider ()
        {
            if (this.provider == this.providers.enabled_provider) {
                return;
            }

            this.set_provider (this.providers.enabled_provider);
        }

        private void on_became_idle (uint32 id)
        {
            // We don't expect idle watch to be called often, so linear scan is good enough.
            unowned Watch? watch = this.watches.find (
                (_id, watch) => {
                    return watch.external_id == id;
                });

            if (watch != null && !watch.invalid) {
                watch.callback ();
            }
        }

        private void on_became_active ()
        {
            var monotonic_time = GLib.get_monotonic_time ();

            this.watches.@foreach (
                (id, watch) => {
                    try {
                        watch.external_id = this.provider.reset_watch (watch.external_id, monotonic_time);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Unable to reset an idle-watch: %s", error.message);
                        return;
                    }
                });
        }

        private void on_notify_enabled_provider (GLib.Object    object,
                                                 GLib.ParamSpec pspec)
        {
            this.update_provider ();
        }

        /**
         * Mutter.IdleMonitor schedules a callback relative to users last activity, not from the time we add a watch.
         *
         * Calculate timeout that is relative to users last activity.
         */
        internal static int64 calculate_absolute_timeout (int64 relative_timeout,
                                                          int64 idle_time,
                                                          int64 reference_time)
                                                          requires (Pomodoro.Timestamp.is_defined (reference_time))
        {
            if (idle_time == 0) {
                return relative_timeout;
            }

            var last_activity_time = GLib.get_monotonic_time () - idle_time;
            var absolute_timeout = relative_timeout + reference_time - last_activity_time;

            return absolute_timeout > 0
                ? absolute_timeout
                : relative_timeout;
        }

        public int64 get_idle_time ()
        {
            if (this.provider == null) {
                return 0;
            }

            try {
                return this.provider.get_idle_time ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Unable to get idle-time: %s", error.message);
                return 0;
            }
        }

        /**
         * Register an idle watch.
         *
         * `reference_time` specifies whether idle-time should be detected from this point of time,
         * otherwise the callback will be called counting from the time of users last activity.
         */
        public uint add_watch (int64                         timeout,
                               owned Pomodoro.BecameIdleFunc callback,
                               int64                         monotonic_time = Pomodoro.Timestamp.UNDEFINED)
        {
            if (timeout == 0) {
                return 0;
            }

            var watch_id = Pomodoro.IdleMonitor.next_id;
            Pomodoro.IdleMonitor.next_id++;

            var watch = new Watch ();
            watch.id = watch_id;
            watch.timeout = timeout;
            watch.callback = (owned) callback;
            watch.reference_time = monotonic_time;
            watch.provider = this.provider;

            if (this.provider != null)
            {
                try {
                    watch.external_id = this.provider.add_watch (timeout, monotonic_time);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Unable to add an idle-watch: %s", error.message);
                }
            }
            else {
                GLib.debug ("Unable to add an idle-watch: no provider.");
            }

            this.watches.insert (watch_id, (owned) watch);

            return watch_id;
        }

        public void remove_watch (uint id)
        {
            unowned Watch? watch = this.watches.lookup (id);

            if (watch == null) {
                return;
            }

            if (this.provider == null)
            {
                watch.invalid = true;
                return;
            }

            try {
                if (watch.external_id != 0) {
                    this.provider.remove_watch (watch.external_id);
                }

                this.watches.remove (id);
            }
            catch (GLib.Error error) {
                GLib.debug ("Error while removing idle watch");
                watch.invalid = true;
            }
        }

        public override void dispose ()
        {
            this.providers.notify["enabled-provider"].disconnect (this.on_notify_enabled_provider);

            this.set_provider (null);

            this.providers = null;
            this.watches = null;

            base.dispose ();
        }
    }
}
