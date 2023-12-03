namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/lightbox.ui")]
    public class Lightbox : Gtk.Window, Gtk.Buildable
    {
        // static int next_instance_id = 1;

        // private int instance_id;

        /**
         * Whether window captures events.
         */
        public bool pass_through {  // TODO: remove?
            get {
                return this._pass_through;
            }
            set {
                this._pass_through = value;

                // this.set_can_focus (!this._pass_through);
                // this.set_can_target (!this._pass_through);
            }
        }

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

        private bool           _pass_through = false;
        protected Gdk.Monitor? _monitor;
        // private bool           grabbed = false;

        static construct
        {
            set_css_name ("lightbox");
            set_auto_startup_notification (false);
        }

        construct
        {
            // TODO: monitor toplevel.state property  https://valadoc.org/gtk4/Gdk.ToplevelState.html

            this.notify["fullscreened"].connect (this.on_fullscreened_notify);

            // Wayland categorizes fullscreen windows and toplevels separately. Indicate from the start that it's an
            // fullscreen window.
            this.fullscreen ();

            // TODO remove
            // this.instance_id = Lightbox.next_instance_id;
            // debug ("Create lightbox %d", this.instance_id);
            // Lightbox.next_instance_id++;
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

        private void on_fullscreened_notify (GLib.Object    object,
                                             GLib.ParamSpec pspec)
        {
            if (!this.fullscreened) {
                GLib.warning ("Window got unfullscreened");
            }
        }

        public override void state_flags_changed (Gtk.StateFlags previous_state_flags)
        {
            base.state_flags_changed (previous_state_flags);

            // TODO: verify that window is fullscreen
            // this.update_grabbed ();
        }

        private bool closing = false;

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
                        window.close ();
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

            // On X11
            // var is_fullscreen =
            // this.ge

            // else {
            //     this.fullscreen ();
            // }
        }

        public override void dispose ()
        {
            this._monitor = null;

            base.dispose ();
        }
    }
}

        /*
        private void update_grabbed ()
        {
            var grabbed = // this.fullscreened &&  // TODO
                          this.is_sensitive () &&
                          this.is_visible ();
                          this.has_focus;

            if (this.grabbed != grabbed)
            {
                debug ("### grabbed = %s", grabbed.to_string ());

                this.grabbed = grabbed;
            }
        }

        // https://valadoc.org/gtk4-x11/Gdk.X11.Display.grab.html
        // https://valadoc.org/gtk4-x11/Gdk.X11.Display.ungrab.html
        // https://valadoc.org/gtk4-x11/Gdk.X11.Display.xevent.html
        // https://valadoc.org/gtk4-x11/Gdk.X11.Display.get_user_time.html

        // https://valadoc.org/gtk4-x11/Gdk.X11.Display.get_primary_monitor.html
        private void fullscreen_on_primary_monitor ()
        {
            // var display = this.get_display ();
            var surface = this.get_native ().get_surface ();
            var toplevel = (Gdk.Toplevel) surface;

            var layout = new Gdk.ToplevelLayout ();
            layout.set_resizable (true);
            layout.set_fullscreen (true, null);

            // TODO: verify that window became fullscreen

            // assert ((toplevel.state & Gdk.ToplevelState.ABOVE) != 0);
            // assert ((toplevel.state & Gdk.ToplevelState.FULLSCREEN) != 0);
            // assert ((toplevel.state & Gdk.ToplevelState.STICKY) != 0);
            // assert ((toplevel.state & Gdk.ToplevelState.SUSPENDED) != 0);
            // SUSPENDED - the surface is not visible to the user
            // assert (toplevel.fullscreen_mode == Gdk.FullscreenMode.ALL_MONITORS);
             // * You can track the result of this operation via the
             // * [property@Gdk.Toplevel:state] property, or by listening to
             // * notifications of the [property@Gtk.Window:fullscreened] property.

            toplevel.present (layout);
        }
        */

