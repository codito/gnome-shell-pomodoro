namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/lightbox.ui")]
    public class Lightbox : Gtk.Window, Gtk.Buildable
    {
        public Gdk.Monitor? monitor {
            get {
                return this._monitor;
            }
            set {
                this._monitor = value;

                if (this._monitor != null) {
                    this.fullscreen_on_monitor (this._monitor);
                }
            }
        }

        protected Gdk.Monitor? _monitor = null;
        private bool           closing = false;

        static construct
        {
            set_css_name ("lightbox");
            set_auto_startup_notification (false);
        }

        construct
        {
            this.notify["fullscreened"].connect (this.on_notify_fullscreened);

            // Wayland categorizes fullscreen windows and toplevels separately. Indicate from the start that it's an
            // fullscreen window.
            this.fullscreen ();
        }

        [GtkCallback]
        private bool on_key_pressed (Gtk.EventControllerKey event_controller,
                                     uint                   keyval,
                                     uint                   keycode,
                                     Gdk.ModifierType       state)
        {
            switch (keyval)
            {
                case Gdk.Key.Escape:
                    this.close ();
                    return true;
            }

            return false;
        }

        private void on_notify_fullscreened (GLib.Object    object,
                                             GLib.ParamSpec pspec)
        {
            if (!this.fullscreened) {
                this.close ();
            }
        }

        /**
         * Invoking close on any of lightboxes within group should propagate to main overlay.
         */
        public new void close ()
        {
            if (this.closing) {
                return;
            }

            this.closing = true;

            var group = this.get_group ();

            if (group != null) {
                group.@list_windows ().@foreach (
                    (window) => {
                        var lightbox = (Pomodoro.Lightbox) window;
                        lightbox.close ();
                    });
            }

            base.close ();
        }

        public override void map ()
        {
            if (this._monitor != null) {
                this.fullscreen_on_monitor (this._monitor);
            }

            base.map ();
        }

        public override void dispose ()
        {
            this._monitor = null;

            base.dispose ();
        }
    }
}
