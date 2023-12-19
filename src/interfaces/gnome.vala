namespace Gnome
{
    [DBus (name = "org.gnome.ScreenSaver")]
    public interface ScreenSaver : GLib.Object
    {
        public abstract async void @lock () throws GLib.DBusError, GLib.IOError;
    }
}
