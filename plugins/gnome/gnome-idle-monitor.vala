/*
 * Adapted from gnome-session/gnome-session/gs-idle-monitor.h
 * and from gnome-desktop/libgnome-session/gnome-idle-monitor.h
 *
 * Copyright (C) 2012 Red Hat, Inc.
 * Copyright (C) 2016 gnome-pomodoro contributors.
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, see <http://www.gnu.org/licenses/>.
 *
 * Original author: William Jon McCann <mccann@jhu.edu>
 */

using GLib;


namespace GnomePlugin
{
    public delegate void IdleMonitorWatchFunc (GnomePlugin.IdleMonitor monitor,
                                               uint32                  id);

    private class IdleMonitorWatch : GLib.InitiallyUnowned
    {
        public unowned GnomePlugin.IdleMonitor   monitor;
        public uint32                            id;
        public uint32                            upstream_id;
        public GnomePlugin.IdleMonitorWatchFunc? callback;
        public uint64                            timeout_msec;

        private static uint32 next_id = 1;

        construct
        {
            this.id = this.get_next_id ();
        }

        public IdleMonitorWatch (GnomePlugin.IdleMonitor     monitor,
                                 uint64                      timeout_msec,
                                 owned IdleMonitorWatchFunc? callback)
        {
            this.monitor = monitor;
            this.timeout_msec = timeout_msec;
            this.callback = (owned) callback;
        }

        private uint32 get_next_id ()
        {
            var next_id = IdleMonitorWatch.next_id;

            IdleMonitorWatch.next_id++;

            return next_id;
        }
    }

    public class IdleMonitor : GLib.Object, GLib.Initable
    {
        private GLib.Cancellable         cancellable;
        private Meta.IdleMonitor         proxy;
        private GLib.HashTable<uint,GnomePlugin.IdleMonitorWatch>           watches;
        private GLib.HashTable<uint,unowned GnomePlugin.IdleMonitorWatch>   watches_by_upstream_id;

        construct
        {
            this.watches = new GLib.HashTable<uint,IdleMonitorWatch>
                                       (null,
                                        null);
            this.watches_by_upstream_id = new GLib.HashTable<uint,unowned IdleMonitorWatch>
                                       (null,
                                        null);

            this.cancellable = new GLib.Cancellable ();
        }

        /**
         * gnome_idle_monitor_new:
         *
         * Returns: a new #GnomeIdleMonitor that tracks the server-global
         * idletime for all devices.
         */
        public IdleMonitor () throws GLib.Error
        {
            ((GLib.Initable) this).init (this.cancellable);
        }

        public override void dispose ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
            }

            base.dispose ();
        }

        public new bool init (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            this.proxy = GLib.Bus.get_proxy_sync<Meta.IdleMonitor>
                                   (GLib.BusType.SESSION,
                                    "org.gnome.Mutter.IdleMonitor",
                                    "/org/gnome/Mutter/IdleMonitor/Core",
                                    GLib.DBusProxyFlags.DO_NOT_AUTO_START);

            this.proxy.watch_fired.connect (this.on_watch_fired);

            this.watches.@foreach ((id, watch) => {
                assert (watch != null);

                if (watch.timeout_msec == 0) {
                    this.add_user_active_watch_internal (watch);
                }
                else {
                    this.add_idle_watch_internal (watch);
                }
            });

            return true;
        }

        private void on_watch_fired (Meta.IdleMonitor proxy,
                                     uint32           upstream_id)
        {
            var watch = this.watches_by_upstream_id.lookup (upstream_id);

            if (watch != null)
            {
                if (watch.callback != null) {
                    watch.callback (watch.monitor, watch.id);
                }

                if (watch.timeout_msec == 0) {
                    this.remove_watch_internal (watch);
                }
            }
        }

        private void add_idle_watch_internal (IdleMonitorWatch watch)
        {
            try {
                // TODO: consider proxy.add_idle_watch to be async
                this.proxy.add_idle_watch (watch.timeout_msec, out watch.upstream_id);

                this.watches_by_upstream_id.insert (watch.upstream_id, watch);
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to add idle watch: %s", error.message);
            }
        }

        private void add_user_active_watch_internal (IdleMonitorWatch watch)
        {
            try {
                // TODO: consider proxy.add_user_active_watch to be async
                this.proxy.add_user_active_watch (out watch.upstream_id);

                this.watches_by_upstream_id.insert (watch.upstream_id, watch);
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to add user-active watch: %s", error.message);
            }
        }

        private void remove_watch_internal (IdleMonitorWatch watch)
        {
            this.watches.remove (watch.id);

            if (watch.upstream_id != 0) {
                this.watches_by_upstream_id.remove (watch.upstream_id);
                watch.upstream_id = 0;
            }
        }

        /**
         * gnome_idle_monitor_add_idle_watch:
         * @monitor: A #GnomeIdleMonitor
         * @interval_msec: The idletime interval, in milliseconds
         * @callback: (allow-none): The callback to call when the user has
         *     accumulated @interval_msec milliseconds of idle time.
         * @user_data: (allow-none): The user data to pass to the callback
         * @notify: A #GDestroyNotify
         *
         * Returns: a watch id
         *
         * Adds a watch for a specific idle time. The callback will be called
         * when the user has accumulated @interval_msec milliseconds of idle time.
         * This function will return an ID that can either be passed to
         * gnome_idle_monitor_remove_watch(), or can be used to tell idle time
         * watches apart if you have more than one.
         *
         * Also note that this function will only care about positive transitions
         * (user's idle time exceeding a certain time). If you want to know about
         * when the user has become active, use
         * gnome_idle_monitor_add_user_active_watch().
         */
        public uint32 add_idle_watch (uint64                      interval_msec,
                                      owned IdleMonitorWatchFunc? callback)
                                      requires (interval_msec > 0)
        {
            var watch = new IdleMonitorWatch (this,
                                              interval_msec,
                                              (owned) callback);

            this.watches.insert (watch.id, watch);

            if (this.proxy != null) {
                this.add_idle_watch_internal (watch);
            }

            return watch.id;
        }

        /**
         * gnome_idle_monitor_add_user_active_watch:
         * @monitor: A #GnomeIdleMonitor
         * @callback: (allow-none): The callback to call when the user is
         *     active again.
         * @user_data: (allow-none): The user data to pass to the callback
         * @notify: A #GDestroyNotify
         *
         * Returns: a watch id
         *
         * Add a one-time watch to know when the user is active again.
         * Note that this watch is one-time and will de-activate after the
         * function is called, for efficiency purposes. It's most convenient
         * to call this when an idle watch, as added by
         * gnome_idle_monitor_add_idle_watch(), has triggered.
         */
        public uint32 add_user_active_watch (owned IdleMonitorWatchFunc callback)
        {
            var watch = new IdleMonitorWatch (this,
                                              0,
                                              (owned) callback);

            this.watches.insert (watch.id, watch);

            if (this.proxy != null) {
                this.add_user_active_watch_internal (watch);
            }

            return watch.id;
        }

        /**
         * gnome_idle_monitor_remove_watch:
         * @monitor: A #GnomeIdleMonitor
         * @id: A watch ID
         *
         * Removes an idle time watcher, previously added by
         * gnome_idle_monitor_add_idle_watch() or
         * gnome_idle_monitor_add_user_active_watch().
         */
        public void remove_watch (uint32 id)
        {
            var watch = this.watches.lookup (id);

            if (watch == null) {
                return;
            }

            if (watch.upstream_id != 0) {
                try {
                    this.proxy.remove_watch (watch.upstream_id);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Failed to remove watch: %s", error.message);
                }
            }

            this.remove_watch_internal (watch);
        }

        /**
         * gnome_idle_monitor_get_idletime:
         * @monitor: A #GnomeIdleMonitor
         *
         * Returns: The current idle time, in milliseconds
         */
        public uint64 get_idletime ()
        {
            uint64 value = 0;

            if (this.proxy != null) {
                try {
                    this.proxy.get_idletime (out value);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Failed to get idletime: %s", error.message);
                }
            }

            return value;
        }
    }
}
