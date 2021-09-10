/*
 * Copyright (c) 2017 gnome-pomodoro contributors
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
 */

using GLib;


namespace Pomodoro
{
    [DBus (name = "org.gnomepomodoro.Pomodoro.Extension")]
    private interface DesktopExtensionInterface : GLib.Object
    {
        public abstract string[] capabilities { owned get; }
    }


    public class DesktopExtension : GLib.Object
    {
        private static Pomodoro.DesktopExtension? instance = null;

        public Pomodoro.CapabilityGroup capabilities { get; construct set; }

        /* extension may vanish for a short time, eg when restarting gnome-shell */
        public uint timeout { get; set; default = 2000; }

        public bool initialized { get; private set; default = false; }

        private DesktopExtensionInterface? proxy = null;
        private uint watcher_id = 0;
        private uint timeout_id = 0;

        construct
        {
            this.capabilities = new Pomodoro.CapabilityGroup ("desktop");
        }

        public DesktopExtension () throws GLib.Error
        {
            this.proxy = GLib.Bus.get_proxy_sync<DesktopExtensionInterface>
                                   (GLib.BusType.SESSION,
                                    "org.gnomepomodoro.Pomodoro.Extension",
                                    "/org/gnomepomodoro/Pomodoro/Extension",
                                    GLib.DBusProxyFlags.NONE);

            this.watcher_id = GLib.Bus.watch_name (
                                        GLib.BusType.SESSION,
                                        "org.gnomepomodoro.Pomodoro.Extension",
                                        GLib.BusNameWatcherFlags.NONE,
                                        this.on_name_appeared,
                                        this.on_name_vanished);
        }

        public static unowned Pomodoro.DesktopExtension get_default ()
        {
            if (DesktopExtension.instance == null) {
                try {
                    var desktop_extension = new Pomodoro.DesktopExtension ();
                    desktop_extension.set_default ();
                }
                catch (GLib.Error error) {
                    GLib.critical ("Failed to create proxy org.gnomepomodoro.Pomodoro.Extension");
                }
            }

            return DesktopExtension.instance;
        }

        public void set_default ()
        {
            DesktopExtension.instance = this;
        }

        public async bool initialize (GLib.Cancellable? cancellable = null)
        {
            var cancellable_handler_id = (ulong) 0;

            if (this.initialized) {
                return true;
            }

            if (cancellable == null || !cancellable.is_cancelled ())
            {
                var handler_id = this.notify["initialized"].connect_after (() => {
                    if (this.initialized) {
                        this.initialize.callback ();
                    }
                });

                if (cancellable != null) {
                    cancellable_handler_id = cancellable.cancelled.connect (() => {
                        this.initialize.callback ();
                    });
                }

                yield;

                this.disconnect (handler_id);

                if (cancellable != null) {
                    /* cancellable.disconnect() causes a deadlock here */
                    GLib.SignalHandler.disconnect (cancellable, cancellable_handler_id);
                }
            }

            return this.initialized;
        }

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
                     requires (this.proxy != null)
        {
            var capabilities_hash = new GLib.HashTable<string, bool> (str_hash, str_equal);

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            foreach (var capability_name in this.proxy.capabilities) {
                capabilities_hash.insert (capability_name, true);

                if (!this.capabilities.contains (capability_name)) {
                    this.capabilities.add (new Pomodoro.Capability (capability_name));
                }
            }

            this.capabilities.@foreach ((capability_name, capability) => {
                if (!capabilities_hash.contains (capability_name)) {
                    this.capabilities.remove (capability_name);
                }
            });

            this.initialized = true;
        }

        private void on_name_vanished (GLib.DBusConnection? connection,
                                       string               name)
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.timeout_id = GLib.Timeout.add (this.timeout, () => {
                this.timeout_id = 0;

                this.capabilities.remove_all ();
                this.initialized = false;

                return GLib.Source.REMOVE;
            });
        }

        public override void dispose ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            if (this.watcher_id != 0) {
                GLib.Bus.unwatch_name (this.watcher_id);
                this.watcher_id = 0;
            }

            this.proxy = null;

            base.dispose ();
        }
    }
}
