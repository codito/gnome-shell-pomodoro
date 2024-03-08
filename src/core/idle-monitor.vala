namespace Pomodoro
{
    public delegate void UserIdleFunc ();
    public delegate void UserActiveFunc ();


    public interface IdleMonitorProvider : Pomodoro.Provider
    {
        public abstract int64 get_idle_time () throws GLib.Error;
        public abstract uint32 add_idle_watch (int64 timeout, int64 monotonic_time) throws GLib.Error;
        public abstract void remove_idle_watch (uint32 id) throws GLib.Error;
        public abstract uint32 reset_idle_watch (uint32 id, int64 monotonic_time) throws GLib.Error;
        public abstract void add_active_watch () throws GLib.Error;
        public abstract void remove_active_watch () throws GLib.Error;

        public abstract signal void became_idle (uint32 id);
        public abstract signal void became_active ();

        /**
         * Mutter.IdleMonitor schedules a callback relative to users last activity, not from the time we add a watch.
         *
         * Calculate timeout that is relative to users last activity.
         */
        public static int64 calculate_absolute_timeout (int64 relative_timeout,
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
    }


    // TODO: should be defined in tests
    public class DummyIdleMonitorProvider : Pomodoro.Provider, Pomodoro.IdleMonitorProvider
    {
        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.available = true;
            this.enabled = true;  // HACK: This is to skip the need for a main loop in tests
        }

        public override async void uninitialize () throws GLib.Error
        {
            this.available = false;
        }

        public override async void enable (GLib.Cancellable? cancellable) throws GLib.Error
        {
        }

        public override async void disable () throws GLib.Error
        {
        }

        public int64 get_idle_time () throws GLib.Error
        {
            return 0;
        }

        public uint32 add_idle_watch (int64 timeout, int64 monotonic_time) throws GLib.Error
        {
            return 1;
        }

        public void remove_idle_watch (uint32 id) throws GLib.Error
        {
        }

        public uint32 reset_idle_watch (uint32 id, int64 monotonic_time) throws GLib.Error
        {
            return 1;
        }

        public void add_active_watch () throws GLib.Error
        {
        }

        public void remove_active_watch () throws GLib.Error
        {
        }
    }


    [SingleInstance]
    public class IdleMonitor : Pomodoro.ProvidedObject<Pomodoro.IdleMonitorProvider>
    {
        private static uint next_id = 1;

        [Compact]
        class Watch
        {
            public uint                                  id = 0;
            public uint32                                external_id = 0;
            public int64                                 timeout = 0;
            public int64                                 reference_time = Pomodoro.Timestamp.UNDEFINED;
            public Pomodoro.UserIdleFunc?                idle_callback = null;
            public Pomodoro.UserActiveFunc?              active_callback = null;
            public unowned Pomodoro.IdleMonitorProvider? provider = null;
            public bool                                  invalid = false;
        }

        private GLib.HashTable<int64?, Watch> watches = null;
        private int64                         last_activity_time = Pomodoro.Timestamp.UNDEFINED;

        /**
         * Used for unittests not to setup providers.
         */
        public IdleMonitor.dummy ()
        {
            this.providers.remove_all ();
            this.providers.add (new Pomodoro.DummyIdleMonitorProvider ());
        }

        construct
        {
            this.watches = new GLib.HashTable<int64?, Watch> (int64_hash, int64_equal);
        }

        private void on_became_idle (uint32 id)
        {
            // We don't expect idle watch to be called often, so linear scan is good enough.
            unowned Watch? watch = this.watches.find (
                (_id, watch) => {
                    return watch.external_id == id;
                });

            if (watch != null && !watch.invalid) {
                watch.idle_callback ();
            }
        }

        private void on_became_active ()
        {
            var monotonic_time = GLib.get_monotonic_time ();

            this.last_activity_time = monotonic_time;

            (unowned Watch)[] watches_to_trigger = new Watch[0];

            this.watches.@foreach (
                (id, watch) => {
                    if (watch.invalid) {
                        return;
                    }

                    if (watch.active_callback != null) {
                        watches_to_trigger += watch;
                    }

                    if (watch.idle_callback != null) {
                        try {
                            // Let the provider decide whether internally it needs a reset.
                            watch.external_id = this.provider.reset_idle_watch (watch.external_id, monotonic_time);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Unable to reset an idle-watch: %s", error.message);
                            return;
                        }
                    }
                });

            for (var index = 0; index < watches_to_trigger.length; index++)
            {
                unowned Watch watch = watches_to_trigger[index];
                watch.active_callback ();
                watch.invalid = true;
            }

            this.watches.foreach_remove (
                (id, watch) => {
                    return watch.invalid && watch.active_callback != null;
                });
        }

        protected override void setup_providers ()
        {
            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Gnome.IdleMonitorProvider (), Pomodoro.Priority.HIGH);
        }

        protected override void provider_enabled (Pomodoro.IdleMonitorProvider provider)
        {
            provider.became_idle.connect (this.on_became_idle);
            provider.became_active.connect (this.on_became_active);

            // Recreate watches with the new provider.
            this.watches.@foreach (
                (id, watch) => {
                    try {
                        watch.external_id = provider.add_idle_watch (watch.timeout, watch.reference_time);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while adding idle watch: %s", error.message);
                    }
                });
        }

        protected override void provider_disabled (Pomodoro.IdleMonitorProvider provider)
        {
            provider.became_idle.disconnect (this.on_became_idle);
            provider.became_active.disconnect (this.on_became_active);

            this.watches.@foreach (
                (id, watch) => {
                    try {
                        provider.remove_idle_watch (watch.external_id);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while removing idle watch: %s", error.message);
                    }

                    watch.external_id = 0;
                });
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

        public bool is_idle (int64 duration = Pomodoro.Interval.SECOND,
                             int64 monotonic_time = Pomodoro.Timestamp.UNDEFINED)
        {
            if (this.provider == null) {
                return false;
            }

            if (duration == 0) {
                return false;
            }

            if (Pomodoro.Timestamp.is_undefined (monotonic_time)) {
                monotonic_time = GLib.get_monotonic_time ();
            }

            if (monotonic_time - this.last_activity_time < duration) {
                return false;
            }

            try {
                return this.provider.get_idle_time () >= duration;
            }
            catch (GLib.Error error) {
                GLib.warning ("Unable to determine if user is idle: %s", error.message);
                return false;
            }
        }

        // public void mark_activity (int64 monotonic_time = Pomodoro.Timestamp.UNDEFINED)
        // {
        //     if (Pomodoro.Timestamp.is_undefined (monotonic_time)) {
        //         monotonic_time = GLib.get_monotonic_time ();
        //     }
        //
        //     if (this.last_activity_time < monotonic_time) {
        //         this.last_activity_time = monotonic_time;
        //     }
        //
        //     // TODO: trigger active watches
        // }

        /**
         * Register an idle watch.
         *
         * `reference_time` specifies whether idle-time should be detected from this point of time,
         * otherwise the callback will be called counting from the time of users last activity.
         */
        public uint add_idle_watch (int64                       timeout,
                                    owned Pomodoro.UserIdleFunc callback,
                                    int64                       monotonic_time = Pomodoro.Timestamp.UNDEFINED)
        {
            if (timeout == 0) {
                return 0;
            }

            var watch_id = Pomodoro.IdleMonitor.next_id;
            Pomodoro.IdleMonitor.next_id++;

            var watch = new Watch ();
            watch.id = watch_id;
            watch.timeout = timeout;
            watch.idle_callback = (owned) callback;
            watch.reference_time = monotonic_time;
            watch.provider = this.provider;

            if (this.provider != null && this.provider.enabled)
            {
                try {
                    watch.external_id = this.provider.add_idle_watch (timeout, monotonic_time);
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

        /**
         * Trigger callback on first user activity counting from now.
         */
        public uint add_active_watch (owned Pomodoro.UserActiveFunc callback,
                                      int64                         monotonic_time = Pomodoro.Timestamp.UNDEFINED)
        {
            var watch_id = Pomodoro.IdleMonitor.next_id;
            Pomodoro.IdleMonitor.next_id++;

            var watch = new Watch ();
            watch.id = watch_id;
            watch.active_callback = (owned) callback;
            watch.reference_time = monotonic_time;
            watch.provider = this.provider;

            if (this.provider != null && this.provider.enabled)
            {
                try {
                    this.provider.add_active_watch ();
                }
                catch (GLib.Error error) {
                    GLib.warning ("Unable to add an active-watch: %s", error.message);
                }
            }
            else {
                GLib.debug ("Unable to add an active-watch: no provider.");
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
                if (watch.idle_callback != null && watch.external_id != 0) {
                    this.provider.remove_idle_watch (watch.external_id);
                }

                if (watch.active_callback != null) {
                    this.provider.remove_active_watch ();
                }

                this.watches.remove (id);
            }
            catch (GLib.Error error) {
                GLib.debug ("Error while removing watch: %s", error.message);
                watch.invalid = true;
            }
        }

        public override void dispose ()
        {
            base.dispose ();

            // Watches are needed for destroying providers during `base.dispose()`.
            this.watches = null;
        }
    }
}
