namespace Pomodoro
{
    public interface TimeZoneMonitorProvider : Pomodoro.Provider
    {
        public abstract string? identifier { get; }
    }


    [SingleInstance]
    public class TimeZoneMonitor : Pomodoro.ProvidedObject<Pomodoro.TimeZoneMonitorProvider>
    {
        public GLib.TimeZone timezone {
            get {
                return this._timezone;
            }
        }

        private GLib.TimeZone? _timezone;

        construct
        {
            this._timezone = new GLib.TimeZone.local ();
        }

        private void update_timezone (string? timezone_identifier)
        {
            GLib.TimeZone? timezone = null;

            if (timezone_identifier != null)
            {
                try {
                    timezone = new GLib.TimeZone.identifier (timezone_identifier);
                }
                catch (GLib.Error error) {
                    GLib.warning ("Could not find timezone \"%s\": %s",
                                  timezone_identifier,
                                  error.message);
                    timezone = new GLib.TimeZone.local ();
                }
            }
            else {
                timezone = new GLib.TimeZone.local ();
            }

            if (this._timezone == null ||
                this._timezone.get_identifier () != timezone.get_identifier ())
            {
                this._timezone = timezone;

                this.notify_property ("timezone");
                this.changed ();
            }
        }

        private void on_notify_identifier (GLib.Object    object,
                                           GLib.ParamSpec pspec)
        {
            var provider = (Pomodoro.TimeZoneMonitorProvider) object;

            this.update_timezone (provider.identifier);
        }

        protected override void setup_providers ()
        {
            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Freedesktop.TimeZoneMonitorProvider ());
        }

        protected override void provider_enabled (Pomodoro.TimeZoneMonitorProvider provider)
        {
            provider.notify["identifier"].connect (this.on_notify_identifier);

            this.update_timezone (provider.identifier);
        }

        protected override void provider_disabled (Pomodoro.TimeZoneMonitorProvider provider)
        {
            provider.notify["identifier"].disconnect (this.on_notify_identifier);
        }

        public signal void changed ();
    }
}
