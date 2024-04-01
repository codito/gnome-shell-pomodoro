namespace Freedesktop
{
    public class LockScreenProvider : Pomodoro.Provider, Pomodoro.LockScreenProvider
    {
        public bool active {
            get {
                return this._active;
            }
        }

        private Freedesktop.LoginSession? session_proxy = null;
        private bool                      _active = false;
        private uint                      watcher_id = 0;
        private ulong                     properties_changed_id = 0;

        private void update_active ()
        {
            var previous_active = this._active;
            var active = this.session_proxy != null
                ? !this.session_proxy.active || this.session_proxy.locked_hint
                : false;

            if (active != previous_active) {
                this._active = active;
                this.notify_property ("active");
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

        private void on_properties_changed (GLib.Variant changed_properties,
                                            string[]     invalidated_properties)
        {
            this.update_active ();
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.watcher_id = GLib.Bus.watch_name (GLib.BusType.SYSTEM,
                                                   "org.freedesktop.login1",
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
                // /org/freedesktop/login1/session/auto do not send notification when properties change,
                // for that we need to connect to the exact session object.
                var manager_proxy = yield GLib.Bus.get_proxy<Freedesktop.LoginManager>
                                    (GLib.BusType.SYSTEM,
                                     "org.freedesktop.login1",
                                     "/org/freedesktop/login1",
                                     GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                                     cancellable);
                var session_auto_proxy = yield GLib.Bus.get_proxy<Freedesktop.LoginSession>
                                    (GLib.BusType.SYSTEM,
                                     "org.freedesktop.login1",
                                     "/org/freedesktop/login1/session/auto",
                                     GLib.DBusProxyFlags.DO_NOT_AUTO_START | GLib.DBusProxyFlags.DO_NOT_CONNECT_SIGNALS,
                                     cancellable);
                var login_sessions = yield manager_proxy.list_sessions ();

                foreach (var login_session in login_sessions)
                {
                    if (login_session.session_id == session_auto_proxy.id) {
                        this.session_proxy = yield GLib.Bus.get_proxy<Freedesktop.LoginSession>
                                    (GLib.BusType.SYSTEM,
                                     "org.freedesktop.login1",
                                     login_session.object_path,
                                     GLib.DBusProxyFlags.DO_NOT_AUTO_START | GLib.DBusProxyFlags.DO_NOT_CONNECT_SIGNALS,
                                     cancellable);
                        break;
                    }
                }

                if (this.session_proxy == null)
                {
                    GLib.warning ("Can't connect to current login session. Lock-screen detection will not work.");

                    this.session_proxy = session_auto_proxy;
                }

                var session_dbus_proxy = (GLib.DBusProxy) this.session_proxy;
                this.properties_changed_id = session_dbus_proxy.g_properties_changed.connect (
                        this.on_properties_changed);

                this.update_active ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing session proxy: %s", error.message);
            }
        }

        public override async void disable () throws GLib.Error
        {
            if (this.properties_changed_id != 0) {
                this.session_proxy.disconnect (this.properties_changed_id);
                this.properties_changed_id = 0;
            }

            this.session_proxy = null;

            this.update_active ();
        }

        public void activate ()
        {
            if (this.session_proxy != null) {
                this.session_proxy.@lock.begin (
                    (obj, res) => {
                        try {
                            this.session_proxy.@lock.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while locking the screen: %s", error.message);
                        }
                    });
            }
            else {
                GLib.warning ("Unable to activate lock-screen.");
            }
        }
    }
}
