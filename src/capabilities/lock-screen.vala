namespace Pomodoro
{
    public class LockScreenCapability : Pomodoro.Capability
    {
        private Freedesktop.Session? session_proxy = null;
        private uint                 watcher_id = 0;

        public LockScreenCapability ()
        {
            base ("lock-screen", Pomodoro.CapabilityPriority.DEFAULT);
        }

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
        {
            try {
                this.session_proxy = GLib.Bus.get_proxy_sync<Freedesktop.Session> (
                        GLib.BusType.SYSTEM,
                        "org.freedesktop.login1",
                        "/org/freedesktop/login1/session/auto",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START);
                this.status = Pomodoro.CapabilityStatus.DISABLED;
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing session proxy: %s", error.message);
                this.status = Pomodoro.CapabilityStatus.UNAVAILABLE;
            }
        }

        private void on_name_vanished (GLib.DBusConnection connection,
                                       string              name)
        {
            this.session_proxy = null;
            this.status = Pomodoro.CapabilityStatus.UNAVAILABLE;
        }

        public override void initialize ()
        {
            this.watcher_id = GLib.Bus.watch_name (GLib.BusType.SYSTEM,
                                                   "org.freedesktop.login1",
                                                   GLib.BusNameWatcherFlags.NONE,
                                                   this.on_name_appeared,
                                                   this.on_name_vanished);

            base.initialize ();
        }

        public override void uninitialize ()
        {
            if (this.watcher_id != 0) {
                GLib.Bus.unwatch_name (this.watcher_id);
                this.watcher_id = 0;
            }

            this.session_proxy = null;

            base.uninitialize ();
        }

        public override void activate ()
        {
            if (this.session_proxy != null) {
                this.session_proxy.@lock.begin ();
            }
            else {
                GLib.warning ("Unable to activate %s.", this.get_debug_name ());
            }
        }

        public override void dispose ()
        {
            this.session_proxy = null;

            base.dispose ();
        }
    }


    public class GnomeLockScreenCapability : Pomodoro.Capability
    {
        private Gnome.ScreenSaver? screen_saver_proxy = null;
        private uint               watcher_id = 0;

        public GnomeLockScreenCapability ()
        {
            base ("lock-screen", Pomodoro.CapabilityPriority.HIGH);
        }

        private void on_name_appeared (GLib.DBusConnection connection,
                                       string              name,
                                       string              name_owner)
        {
            try {
                this.screen_saver_proxy = GLib.Bus.get_proxy_sync<Gnome.ScreenSaver> (
                        GLib.BusType.SESSION,
                        "org.gnome.ScreenSaver",
                        "/org/gnome/ScreenSaver",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START);
                this.status = Pomodoro.CapabilityStatus.DISABLED;
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing session proxy: %s", error.message);
                this.status = Pomodoro.CapabilityStatus.UNAVAILABLE;
            }
        }

        private void on_name_vanished (GLib.DBusConnection connection,
                                       string              name)
        {
            this.screen_saver_proxy = null;
            this.status = Pomodoro.CapabilityStatus.UNAVAILABLE;
        }

        public override void initialize ()
        {
            this.watcher_id = GLib.Bus.watch_name (GLib.BusType.SESSION,
                                                   "org.gnome.ScreenSaver",
                                                   GLib.BusNameWatcherFlags.NONE,
                                                   this.on_name_appeared,
                                                   this.on_name_vanished);

            base.initialize ();
        }

        public override void uninitialize ()
        {
            if (this.watcher_id != 0) {
                GLib.Bus.unwatch_name (this.watcher_id);
                this.watcher_id = 0;
            }

            this.screen_saver_proxy = null;

            base.uninitialize ();
        }

        public override void activate ()
        {
            if (this.screen_saver_proxy != null) {
                this.screen_saver_proxy.@lock.begin ();
            }
            else {
                GLib.warning ("Unable to activate %s.", this.get_debug_name ());
            }
        }

        public override void dispose ()
        {
            this.screen_saver_proxy = null;

            base.dispose ();
        }
    }
}
