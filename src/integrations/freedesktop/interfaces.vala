namespace Freedesktop
{
    public struct Session
    {
        public string session_id;
        public uint32 user_id;
        public string user_name;
        public string seat_id;
        public string object_path;
    }


    [DBus (name = "org.freedesktop.login1.Manager")]
    public interface LoginManager : GLib.Object
    {
        public abstract async Session[] list_sessions () throws GLib.DBusError, GLib.IOError;

        public signal void prepare_for_sleep (bool active);
    }


    [DBus (name = "org.freedesktop.login1.Session")]
    public interface LoginSession : GLib.Object
    {
        public abstract string id { owned get; }
        public abstract bool active { get; }
        public abstract bool locked_hint { get; }

        [DBus (no_reply = true)]
        public abstract async void @lock () throws GLib.DBusError, GLib.IOError;
    }


    [DBus (name = "org.freedesktop.ScreenSaver")]
    public interface ScreenSaver : GLib.Object
    {
        public abstract async bool get_active () throws GLib.DBusError, GLib.IOError;

        public signal void active_changed (bool active);
    }


    [DBus (name = "org.freedesktop.Notifications")]
    public interface Notifications : GLib.Object
    {
        public abstract async void get_capabilities (out string[] capabilities) throws GLib.DBusError, GLib.IOError;

        public abstract async void get_server_information (out string name,
                                                           out string vendor,
                                                           out string version,
                                                           out string spec_version) throws GLib.DBusError, GLib.IOError;
    }
}
