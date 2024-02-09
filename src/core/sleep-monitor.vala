namespace Pomodoro
{
    public interface SleepMonitorProvider : Pomodoro.Provider
    {
        public signal void prepare_for_sleep ();
        public signal void woke_up ();
    }


    [SingleInstance]
    public class SleepMonitor : Pomodoro.ProvidedObject<Pomodoro.SleepMonitorProvider>
    {
        private void on_prepare_for_sleep ()
        {
            this.prepare_for_sleep ();
        }

        private void on_woke_up ()
        {
            this.woke_up ();
        }

        protected override void setup_providers ()
        {
            // TODO: Providers should register themselves in a static constructors, but can't make it work...
            this.providers.add (new Freedesktop.SleepMonitorProvider ());
        }

        protected override void provider_enabled (Pomodoro.SleepMonitorProvider provider)
        {
            provider.prepare_for_sleep.connect (this.on_prepare_for_sleep);
            provider.woke_up.connect (this.on_woke_up);
        }

        protected override void provider_disabled (Pomodoro.SleepMonitorProvider provider)
        {
            provider.prepare_for_sleep.disconnect (this.on_prepare_for_sleep);
            provider.woke_up.disconnect (this.on_woke_up);
        }

        public signal void prepare_for_sleep ();
        public signal void woke_up ();
    }
}
