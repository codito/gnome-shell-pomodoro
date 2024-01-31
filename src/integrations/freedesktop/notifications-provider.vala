namespace Freedesktop
{
    public class NotificationsProvider : Pomodoro.Provider, Pomodoro.NotificationsProvider
    {
        public string name {
            get {
                return this._name;
            }
        }

        public string vendor {
            get {
                return this._vendor;
            }
        }

        public string version {
            get {
                return this._version;
            }
        }

        public string spec_version {
            get {
                return this._spec_version;
            }
        }

        public bool has_actions {
            get {
                return this._has_actions;
            }
        }

        private uint   watcher_id = 0;
        private string _name = null;
        private string _vendor = null;
        private string _version = null;
        private string _spec_version = null;
        private bool   _has_actions = false;

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
        {
            this.available = true;
        }

        private void on_name_vanished (GLib.DBusConnection connection,
                                       string              name)
        {
            this.available = false;
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.watcher_id = GLib.Bus.watch_name (GLib.BusType.SESSION,
                                                   "org.freedesktop.Notifications",
                                                   GLib.BusNameWatcherFlags.NONE,
                                                   this.on_name_appeared,
                                                   this.on_name_vanished);
        }

        public override async void uninitialize () throws GLib.Error
        {
            if (this.watcher_id != 0) {
                GLib.Bus.unwatch_name (this.watcher_id);
                this.watcher_id = 0;
            }
        }

        public override async void enable (GLib.Cancellable? cancellable) throws GLib.Error
        {
            string[] capabilities;

            var proxy = yield GLib.Bus.get_proxy<Freedesktop.Notifications> (
                        GLib.BusType.SESSION,
                        "org.freedesktop.Notifications",
                        "/org/freedesktop/Notifications",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START | GLib.DBusProxyFlags.DO_NOT_CONNECT_SIGNALS);

            yield proxy.get_server_information (out this._name,
                                                out this._vendor,
                                                out this._version,
                                                out this._spec_version);
            yield proxy.get_capabilities (out capabilities);

            for (var index = 0; index < capabilities.length; index++)
            {
                switch (capabilities[index])
                {
                    case "actions":
                        this._has_actions = true;
                        break;

                    default:
                        break;
                }
            }
        }

        public override async void disable () throws GLib.Error
        {
            this._name = null;
            this._vendor = null;
            this._version = null;
            this._spec_version = null;
            this._has_actions = false;
        }
    }
}
