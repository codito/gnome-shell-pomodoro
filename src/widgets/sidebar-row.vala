namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/sidebar-row.ui")]
    public class SidebarRow : Gtk.Box
    {
        public string icon_name {
            get {
                return this._icon_name;
            }
            set {
                this._icon_name = value;
                this.icon.visible = value != "";
            }
        }

        public string title { get; set; }

        public Gtk.Widget? suffix {
            get {
                return this._suffix;
            }
            set {
                if (this._suffix != null) {
                    base.remove (this._suffix);
                }

                this._suffix = value;

                if (this._suffix != null) {
                    base.append (this._suffix);
                }
            }
        }

        [GtkChild]
        private unowned Gtk.Image icon;

        private string _icon_name;
        private Gtk.Widget? _suffix = null;

        static construct
        {
            set_css_name ("row");
        }

        public override void dispose ()
        {
            this._suffix = null;

            base.dispose ();
        }
    }
}
