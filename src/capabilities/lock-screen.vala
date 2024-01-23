namespace Pomodoro
{
    public class LockScreenCapability : Pomodoro.Capability
    {
        private Pomodoro.LockScreen? lockscreen;

        public LockScreenCapability ()
        {
            base ("lock-screen", Pomodoro.CapabilityPriority.DEFAULT);
        }

        private void on_notify_available (GLib.Object    object,
                                          GLib.ParamSpec pspec)
        {
            this.status = this.lockscreen.available
                ? Pomodoro.CapabilityStatus.DISABLED
                : Pomodoro.CapabilityStatus.UNAVAILABLE;
        }

        public override void initialize ()
        {
            this.lockscreen = new Pomodoro.LockScreen ();
            this.lockscreen.notify["available"].connect (this.on_notify_available);

            this.status = this.lockscreen.available
                ? Pomodoro.CapabilityStatus.DISABLED
                : Pomodoro.CapabilityStatus.UNAVAILABLE;
        }

        public override void uninitialize ()
        {
            this.lockscreen = null;

            base.uninitialize ();
        }

        public override void activate ()
        {
            this.lockscreen?.activate ();
        }
    }
}
