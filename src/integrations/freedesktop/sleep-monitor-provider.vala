namespace Freedesktop
{
    public class SleepMonitorProvider : Pomodoro.Provider, Pomodoro.SleepMonitorProvider
    {
        private Freedesktop.LoginManager? login_manager_proxy = null;
        private uint                      watcher_id = 0;

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

        private void on_prepare_for_sleep (Freedesktop.LoginManager proxy,
                                           bool                     about_to_suspend)
        {
            if (about_to_suspend) {
                this.prepare_for_sleep ();
            }
            else {
                this.woke_up ();
            }
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
            this.login_manager_proxy = yield GLib.Bus.get_proxy<Freedesktop.LoginManager>
                                   (GLib.BusType.SYSTEM,
                                    "org.freedesktop.login1",
                                    "/org/freedesktop/login1");
            this.login_manager_proxy.prepare_for_sleep.connect (this.on_prepare_for_sleep);
        }

        public override async void disable () throws GLib.Error
        {
            this.login_manager_proxy.prepare_for_sleep.disconnect (this.on_prepare_for_sleep);
            this.login_manager_proxy = null;
        }
    }
}
