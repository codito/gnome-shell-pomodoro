namespace Freedesktop
{
    [DBus (name = "org.freedesktop.login1.Manager")]
    public interface LoginManager : GLib.Object
    {
        public signal void prepare_for_sleep (bool active);
    }
}
