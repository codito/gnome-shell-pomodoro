namespace Freedesktop
{
    [DBus (name = "org.freedesktop.login1.Manager")]
    public interface LoginManager : GLib.Object
    {
        public signal void prepare_for_sleep (bool active);
    }


    [DBus (name = "org.freedesktop.login1.Session")]
    public interface Session : GLib.Object
    {
        public abstract async void @lock () throws GLib.DBusError, GLib.IOError;
    }


    // [DBus (name = "org.freedesktop.ScreenSaver")]
    // public interface ScreenSaver : GLib.Object
    // {
    //     public abstract async void @lock () throws GLib.DBusError, GLib.IOError;
    // }


    // [DBus (name = "org.freedesktop.Notifications")]
    // public interface Notifications : GLib.Object
    // {
    //     public abstract async void get_capabilities (out string[] capabilities) throws GLib.DBusError, GLib.IOError;
    // }
}
