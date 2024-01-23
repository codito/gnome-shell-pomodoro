namespace Pomodoro
{
    public interface LockScreenProvider : Pomodoro.Provider
    {
        public abstract bool active { get; }

        public abstract void activate ();
    }


    [SingleInstance]
    public class LockScreen : Pomodoro.ProvidedObject<Pomodoro.LockScreenProvider>
    {
        public bool active {
            get {
                return this.provider != null ? this.provider.active : false;
            }
        }

        private void on_notify_active (GLib.Object    object,
                                       GLib.ParamSpec pspec)
        {
            this.notify_property ("active");
        }

        protected override void initialize (Pomodoro.ProviderSet<Pomodoro.LockScreenProvider> providers)
        {
            providers.add (new Freedesktop.LockScreenProvider ());
        }

        protected override void provider_set (Pomodoro.LockScreenProvider? provider)
        {
            if (provider != null) {
                provider.notify["active"].connect (this.on_notify_active);
            }
        }

        protected override void provider_unset (Pomodoro.LockScreenProvider? provider)
        {
            if (provider != null) {
                provider.notify["active"].disconnect (this.on_notify_active);
            }
        }

        public void activate ()
        {
            if (this.provider != null) {
                this.provider.activate ();
            }
            else {
                GLib.debug ("Unable to activate lock-screen: no provider");
            }
        }
    }
}
