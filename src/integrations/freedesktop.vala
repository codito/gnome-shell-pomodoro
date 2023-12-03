namespace Freedesktop
{
    [DBus (name = "org.freedesktop.login1.Manager")]
    public interface LoginManager : GLib.Object
    {
        public signal void prepare_for_sleep (bool active);
    }

    // bus: org.freedesktop.login1
    // object: /org/freedesktop/login1/session/auto
    // interface: org.freedesktop.login1.Session
    [DBus (name = "org.freedesktop.login1.Session")]
    public interface Session : GLib.Object
    {
        public abstract void @lock () throws GLib.DBusError, GLib.IOError;
    }


    [DBus (name = "org.freedesktop.ScreenSaver")]
    public interface ScreenSaver : GLib.Object
    {
        public abstract void @lock () throws GLib.DBusError, GLib.IOError;
    }
}
