namespace Pomodoro
{
    public enum ProviderPriority
    {
        LOW = 0,
        DEFAULT = 1,
        HIGH = 2
    }


    /**
     * Provider class offer an integration with a specific service.
     *
     * It has many similarities with the `Capability` class, as it also needs to be initialized, enabled, disabled...
     * However, capabilities focus on specific features. Providers are meant to be lower-level and integrate with
     * external APIs or services. For instance a screen-saver, integration may be used by several capabilities;
     * if the screen-saver has several backend implementations consider implementing a provider.
     */
    public abstract class Provider : GLib.Object
    {
        public bool available {
            get;
            protected set;
            default = false;
        }

        public abstract async void initialize () throws GLib.Error;

        public abstract async void enable () throws GLib.Error;

        public abstract async void disable () throws GLib.Error;

        public abstract async void destroy () throws GLib.Error;
    }
}
