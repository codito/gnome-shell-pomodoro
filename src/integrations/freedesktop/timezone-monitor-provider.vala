namespace Freedesktop
{
    public class TimeZoneMonitorProvider : Pomodoro.Provider, Pomodoro.TimeZoneMonitorProvider
    {
        public string? identifier {
            get {
                return this._identifier;
            }
        }

        private Freedesktop.TimeDate? timedate_proxy = null;
        private uint                  watcher_id = 0;
        private ulong                 properties_changed_id = 0;
        private string?               _identifier = null;

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
            var identifier_value = changed_properties.lookup_value ("Timezone",
                                                                    GLib.VariantType.STRING);
            if (identifier_value == null) {
                return;
            }

            // `org.freedesktop.timedate1` service can be chatty, so detect no-changes early.
            var identifier = identifier_value.get_string ();

            if (this._identifier != identifier)
            {
                this._identifier = identifier;

                this.notify_property ("identifier");
            }
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.watcher_id = GLib.Bus.watch_name (GLib.BusType.SYSTEM,
                                                   "org.freedesktop.timedate1",
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
            this.timedate_proxy = yield GLib.Bus.get_proxy<Freedesktop.TimeDate>
                                   (GLib.BusType.SYSTEM,
                                    "org.freedesktop.timedate1",
                                    "/org/freedesktop/timedate1");

            var timedate_dbus_proxy = (GLib.DBusProxy) this.timedate_proxy;
            this.properties_changed_id = timedate_dbus_proxy.g_properties_changed.connect (
                    this.on_properties_changed);

            this._identifier = this.timedate_proxy.timezone;
            this.notify_property ("identifier");
        }

        public override async void disable () throws GLib.Error
        {
            if (this.properties_changed_id != 0) {
                this.timedate_proxy.disconnect (this.properties_changed_id);
                this.properties_changed_id = 0;
            }

            this.timedate_proxy = null;
        }
    }
}
