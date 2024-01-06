namespace Pomodoro
{
    errordomain SleepMonitorError {
        NOT_INITIALIZED
    }


    [SingleInstance]
    public class SleepMonitor : GLib.Object, GLib.AsyncInitable
    {
        private Freedesktop.LoginManager? login_manager_proxy = null;

        construct
        {
        }

        public async new bool init_async (int               io_priority = GLib.Priority.DEFAULT,
                                          GLib.Cancellable? cancellable = null)
                                          throws GLib.Error
        {
            this.login_manager_proxy = yield GLib.Bus.get_proxy<Freedesktop.LoginManager>
                                   (GLib.BusType.SYSTEM,
                                    "org.freedesktop.login1",
                                    "/org/freedesktop/login1");

            if (this.login_manager_proxy == null) {
                throw new SleepMonitorError.NOT_INITIALIZED ("Failed to connect to LoginManager D-Bus service");
            }

            this.login_manager_proxy.prepare_for_sleep.connect (this.on_prepare_for_sleep);

            return true;
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

        public signal void prepare_for_sleep ();
        public signal void woke_up ();
    }
}
