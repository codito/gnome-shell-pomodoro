namespace Gnome
{
    public class ScreenSaverProvider : Pomodoro.Provider, Pomodoro.ScreenSaverProvider
    {
        public bool active {
            get {
                return this._active;
            }
        }

        private Gnome.ScreenSaver? screensaver_proxy = null;
        private uint               watcher_id = 0;
        private bool               _active = false;
        private ulong              active_changed_id = 0;

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

        private void on_active_changed (bool active)
        {
            if (this._active != active) {
                this._active = active;
                this.notify_property ("active");
            }
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.watcher_id = GLib.Bus.watch_name (GLib.BusType.SESSION,
                                                   "org.gnome.ScreenSaver",
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
            try {
                this.screensaver_proxy = yield GLib.Bus.get_proxy<Gnome.ScreenSaver>
                                    (GLib.BusType.SESSION,
                                     "org.gnome.ScreenSaver",
                                     "/org/gnome/ScreenSaver",
                                     GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                                     cancellable);
                this._active = yield this.screensaver_proxy.get_active ();

                this.active_changed_id = this.screensaver_proxy.active_changed.connect (this.on_active_changed);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing session proxy: %s", error.message);
            }
        }

        public override async void disable () throws GLib.Error
        {
            if (this.active_changed_id != 0) {
                this.screensaver_proxy.disconnect (this.active_changed_id);
                this.active_changed_id = 0;
            }

            this.screensaver_proxy = null;

            if (this._active) {
                this._active = false;
                this.notify_property ("active");
            }
        }
    }
}
