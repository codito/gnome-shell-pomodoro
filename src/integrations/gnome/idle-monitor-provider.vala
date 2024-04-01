namespace Gnome
{
    public class IdleMonitorProvider : Pomodoro.Provider, Pomodoro.IdleMonitorProvider
    {
        /**
         * We typically define the timeout relative to a given reference-time. Mutter counts idle-time from the
         * perspective of a user and refers to idle-time as an interval since the watch may be triggered repeatedly.
         * Allow some tolerance in order not to schedule relative timeouts, and prefer native intervals.
         */
        private const int64 TIMEOUT_TOLERANCE = 100 * Pomodoro.Interval.MILLISECOND;

        [Compact]
        class Watch
        {
            public uint32 id = 0;
            public int64  absolute_timeout = 0;
            public int64  relative_timeout = 0;
            public int64  reference_time = Pomodoro.Timestamp.UNDEFINED;
            public bool   has_active_watch = false;
            public bool   invalid = false;
        }

        private Gnome.IdleMonitor?            proxy = null;
        private GLib.Cancellable?             cancellable = null;
        private uint                          dbus_watcher_id = 0;
        private GLib.HashTable<int64?, Watch> watches = null;
        private uint32                        active_watch_id = 0;
        private uint                          active_watch_use_count = 0;
        private int                           idle_time_freeze_count = 0;
        private int64                         idle_time = -1;

        construct
        {
            this.watches = new GLib.HashTable<int64?, Watch> (int64_hash, int64_equal);
        }

        private inline int64 from_milliseconds (uint64 milliseconds)
        {
            return (int64) milliseconds.clamp (0, int64.MAX / Pomodoro.Interval.MILLISECOND)
                    * Pomodoro.Interval.MILLISECOND;
        }

        private inline uint64 to_milliseconds (int64 interval)
        {
            return (uint64) int64.max (interval, 0) / Pomodoro.Interval.MILLISECOND;
        }

        private void freeze_idle_time ()
        {
            this.idle_time_freeze_count++;
        }

        private void thaw_idle_time ()
        {
            this.idle_time_freeze_count--;
        }

        private void remove_active_watch_internal () throws GLib.Error
        {
            if (this.active_watch_id != 0)
            {
                var watch_id = this.active_watch_id;

                this.active_watch_id = 0;
                this.active_watch_use_count = 0;

                this.proxy.remove_watch (watch_id);
            }
        }

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
        {
            this.available = true;
        }

        private void on_name_vanished (GLib.DBusConnection? connection,
                                       string               name)
        {
            this.available = false;
        }

        private void on_became_active ()
        {
            try {
                this.remove_active_watch_internal ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while removing active-watch: %s", error.message);
            }

            this.became_active ();
        }

        private void on_became_idle (Watch watch)
        {
            var monotonic_time = GLib.get_monotonic_time ();
            var min_elapsed = int64.max (watch.relative_timeout - TIMEOUT_TOLERANCE,
                                         watch.relative_timeout / 2);

            if (monotonic_time - watch.reference_time >= min_elapsed) {
                this.became_idle (watch.id);
            }
        }

        private void on_watch_fired (Gnome.IdleMonitor idle_monitor,
                                     uint32            id)
        {
            if (id == 0) {
                return;
            }

            this.freeze_idle_time ();

            if (id == this.active_watch_id)
            {
                this.idle_time = 0;
                this.on_became_active ();
            }
            else {
                unowned Watch? watch = this.watches.lookup (id);

                if (watch != null && !watch.invalid) {
                    this.idle_time = watch.absolute_timeout;
                    this.on_became_idle (watch);
                }
            }

            this.thaw_idle_time ();
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            if (this.dbus_watcher_id == 0) {
                this.dbus_watcher_id = GLib.Bus.watch_name (GLib.BusType.SESSION,
                                                            "org.gnome.Mutter.IdleMonitor",
                                                            GLib.BusNameWatcherFlags.NONE,
                                                            this.on_name_appeared,
                                                            this.on_name_vanished);
            }
        }

        public override async void uninitialize () throws GLib.Error
        {
            if (this.dbus_watcher_id != 0) {
                GLib.Bus.unwatch_name (this.dbus_watcher_id);
                this.dbus_watcher_id = 0;
            }

            this.cancellable = null;
        }

        public override async void enable (GLib.Cancellable? cancellable) throws GLib.Error
        {
            if (this.proxy != null) {
                return;
            }

            this.cancellable = new GLib.Cancellable ();

            this.proxy = yield GLib.Bus.get_proxy<Gnome.IdleMonitor> (
                    GLib.BusType.SESSION,
                    "org.gnome.Mutter.IdleMonitor",
                    "/org/gnome/Mutter/IdleMonitor/Core",
                    GLib.DBusProxyFlags.DO_NOT_LOAD_PROPERTIES,
                    this.cancellable);

            this.proxy.watch_fired.connect (this.on_watch_fired);
        }

        public override async void disable () throws GLib.Error
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }

            if (this.proxy == null) {
                return;
            }

            this.proxy.watch_fired.disconnect (this.on_watch_fired);

            uint32[] ids = {};

            this.watches.@foreach (
                (id, watch) => {
                    ids += watch.id;
                });

            for (var index = 0; index < ids.length; index++) {
                this.remove_idle_watch (ids[index]);
            }

            this.remove_active_watch_internal ();

            this.proxy = null;
        }

        public int64 get_idle_time () throws GLib.Error
        {
            if (this.idle_time_freeze_count > 0 && this.idle_time >= 0) {
                return this.idle_time;
            }

            if (this.proxy == null) {
                return 0;
            }

            var idle_time = this.from_milliseconds (this.proxy.get_idletime ());

            if (this.idle_time_freeze_count > 0) {
                this.idle_time = idle_time;
            }

            return idle_time;
        }

        public uint32 add_idle_watch (int64 timeout,
                                      int64 monotonic_time) throws GLib.Error
                                      requires (this.proxy != null)
        {
            int64 relative_timeout = timeout;
            int64 absolute_timeout = timeout;
            int64 idle_time;

            if (Pomodoro.Timestamp.is_undefined (monotonic_time)) {
                monotonic_time = GLib.get_monotonic_time () - relative_timeout;
            }
            else {
                idle_time = this.get_idle_time ();

                absolute_timeout = calculate_absolute_timeout (relative_timeout,
                                                               idle_time,
                                                               monotonic_time);
                if ((absolute_timeout - relative_timeout).abs () < TIMEOUT_TOLERANCE) {
                    absolute_timeout = relative_timeout;
                }
            }

            var watch_id = this.proxy.add_idle_watch (this.to_milliseconds (absolute_timeout));

            var watch = new Watch ();
            watch.id = watch_id;
            watch.relative_timeout = relative_timeout;
            watch.absolute_timeout = absolute_timeout;
            watch.reference_time = monotonic_time;

            unowned Watch _watch = watch;

            this.watches.insert (watch_id, (owned) watch);

            if (!_watch.has_active_watch && _watch.absolute_timeout != _watch.relative_timeout)
            {
                try {
                    this.add_active_watch ();
                    _watch.has_active_watch = true;
                }
                catch (GLib.Error error) {
                    GLib.debug ("Unable to add active watch: %s", error.message);

                    this.remove_idle_watch (watch_id);

                    throw error;
                }
            }

            return watch_id;
        }

        public void remove_idle_watch (uint32 id)
                                       requires (this.proxy != null)
        {
            unowned Watch? watch = this.watches.lookup (id);

            if (watch == null) {
                return;
            }

            watch.invalid = true;

            if (watch.has_active_watch) {
                try {
                    this.remove_active_watch ();
                    watch.has_active_watch = false;
                }
                catch (GLib.Error error) {
                    GLib.warning ("Unable to remove active watch: %s", error.message);
                }
            }

            try {
                this.proxy.remove_watch (watch.id);

                if (!watch.has_active_watch) {
                    this.watches.remove (id);
                }
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while removing idle watch: %s", error.message);
            }
        }

        public uint32 reset_idle_watch (uint32 id,
                                        int64  monotonic_time) throws GLib.Error
                                        requires (this.proxy != null)
        {
            unowned Watch? watch = this.watches.lookup (id);

            if (watch == null || watch.absolute_timeout == watch.relative_timeout) {
                return id;
            }

            var new_id = this.add_idle_watch (watch.relative_timeout, monotonic_time);

            try {
                this.proxy.remove_watch (watch.id);
            }
            catch (GLib.Error error)
            {
                this.remove_idle_watch (new_id);

                throw error;
            }

            return new_id;
        }

        public void add_active_watch () throws GLib.Error
                                      requires (this.proxy != null)
        {
            if (this.active_watch_id == 0) {
                this.active_watch_id = this.proxy.add_user_active_watch ();
            }

            this.active_watch_use_count++;
        }

        public void remove_active_watch () throws GLib.Error
                                         requires (this.active_watch_use_count > 0)
                                         ensures (this.active_watch_use_count >= 0)
        {
            if (this.active_watch_use_count > 1) {
                this.active_watch_use_count--;
            }
            else if (this.active_watch_use_count == 1) {
                this.remove_active_watch_internal ();
            }
        }

        public override void dispose ()
        {
            this.watches = null;

            base.dispose ();
        }
    }
}
