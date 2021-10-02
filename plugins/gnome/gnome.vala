namespace Gnome
{
    public enum ExtensionState
    {
        ENABLED = 1,
        DISABLED = 2,
        ERROR = 3,
        OUT_OF_DATE = 4,
        DOWNLOADING = 5,
        INITIALIZED = 6,

        /* Used as an error state for operations on unknown extensions,
         * should never be in a real extensionMeta object.
         */
        UNINSTALLED = 99;

        public string to_string ()
        {
            switch (this)
            {
                case ENABLED:
                    return "enabled";

                case DISABLED:
                    return "disabled";

                case ERROR:
                    return "error";

                case OUT_OF_DATE:
                    return "out-of-date";

                case DOWNLOADING:
                    return "downloading";

                case INITIALIZED:
                    return "initialized";

                case UNINSTALLED:
                    return "uninstalled";

                default:
                    assert_not_reached ();
            }
        }
    }

    public struct ExtensionInfo
    {
        public string         uuid;
        public string         path;
        public string         version;
        public ExtensionState state;

        public ExtensionInfo.with_defaults (string uuid)
        {
            this.uuid = uuid;
            this.path = "";
            this.version = "";
            this.state = ExtensionState.UNINSTALLED;
        }

        public ExtensionInfo.deserialize (string                              uuid,
                                          GLib.HashTable<string,GLib.Variant> data) throws GLib.Error
        {
            this.uuid = data.contains ("uuid")
                            ? data.lookup ("uuid").get_string ()
                            : uuid;
            this.path = data.contains ("path")
                            ? data.lookup ("path").get_string ()
                            : "";
            this.version = data.contains ("version")
                            ? data.lookup ("version").get_string ()
                            : "";
            this.state = data.contains ("state")
                            ? (Gnome.ExtensionState) data.lookup ("state").get_double ()
                            : Gnome.ExtensionState.UNINSTALLED;
        }
    }

    [DBus (name = "org.gnome.Shell")]
    public interface Shell : GLib.Object
    {
        public abstract string mode { owned get; }
        public abstract string shell_version { owned get; }

        public abstract void eval
                                       (string     script,
                                        out bool   success,
                                        out string result)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract bool grab_accelerator
                                       (string     accelerator,
                                        uint32     mode_flags,
                                        uint32     grab_flags,
                                        out uint32 action)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract bool ungrab_accelerator
                                       (uint32   action,
                                        out bool success)
                                        throws GLib.DBusError, GLib.IOError;

        public signal void accelerator_activated
                                       (uint32 action,
                                        uint32 device_id,
                                        uint32 timestamp);
    }

    [DBus (name = "org.gnome.Shell.Extensions")]
    public interface ShellExtensions : GLib.Object
    {
        public abstract bool user_extensions_enabled { get; set; }
        public abstract string shell_version { owned get; }

        public abstract async bool enable_extension
                                       (string uuid,
                                        Cancellable? cancellable = null)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract async bool disable_extension
                                       (string uuid,
                                        Cancellable? cancellable = null)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract async bool uninstall_extension
                                       (string uuid,
                                        Cancellable? cancellable = null)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract async HashTable<string,Variant> get_extension_info
                                       (string       uuid,
                                        Cancellable? cancellable = null)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract void get_extension_errors
                                       (string       uuid,
                                        out string[] errors)
                                        throws GLib.DBusError, GLib.IOError;

        public signal void extension_state_changed
                                       (string uuid,
                                        HashTable<string,Variant> state);
    }
}


/* Mutter interfaces */
namespace Meta
{
    [DBus (name = "org.gnome.Mutter.IdleMonitor")]
    public interface IdleMonitor : GLib.Object
    {
        public abstract void get_idletime
                                       (out uint64 idletime)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract void add_idle_watch
                                       (uint64     interval,
                                        out uint32 id)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract void add_user_active_watch
                                       (out uint32 id)
                                        throws GLib.DBusError, GLib.IOError;

        public abstract void remove_watch
                                       (uint id)
                                        throws GLib.DBusError, GLib.IOError;

        public signal void watch_fired (uint32 id);
    }
}
