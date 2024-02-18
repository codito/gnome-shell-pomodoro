namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/screen-overlay.ui")]
    public class ScreenOverlay : Pomodoro.Lightbox
    {
        [GtkChild]
        private unowned Gtk.Button lock_screen_button;

        private Pomodoro.LockScreen? lock_screen;

        construct
        {
            this.lock_screen = new Pomodoro.LockScreen ();

            this.lock_screen.bind_property ("enabled",
                                            this.lock_screen_button,
                                            "visible",
                                            GLib.BindingFlags.SYNC_CREATE);
        }

        [GtkCallback]
        private void on_lock_screen_button_clicked (Gtk.Button button)
        {
            this.lock_screen.activate ();
        }

        [GtkCallback]
        private void on_close_button_clicked (Gtk.Button button)
        {
            this.close ();
        }

        // public override void map ()
        // {
        //     base.map ();
        //
        //    // TODO: Reset user idle-time to delay the screen-saver.
        //    // Pomodoro.wake_up_screen ();
        // }

        public override void dispose ()
        {
            this.lock_screen = null;

            base.dispose ();
        }
    }
}
