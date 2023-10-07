namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/log-scale-row.ui")]
    public class LogScaleRow : Adw.ActionRow
    {
        public Gtk.Adjustment adjustment {
            get {
                return this._adjustment;
            }
            set {
                if (this._adjustment != null) {
                    this._adjustment.disconnect (this.value_changed_id);
                    this.value_changed_id = 0;
                }

                this._adjustment = value;

                if (this._adjustment != null) {
                    this.value_changed_id = this._adjustment.value_changed.connect (this.on_value_changed);
                }
            }
        }

        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label value_label;
        [GtkChild]
        private unowned Pomodoro.LogScale scale;

        private Gtk.Adjustment _adjustment;
        private ulong          value_changed_id = 0;

        construct
        {
            this.bind_property ("title", this.title_label, "label", GLib.BindingFlags.SYNC_CREATE);
            this.bind_property ("adjustment", this.scale, "adjustment", GLib.BindingFlags.SYNC_CREATE);

            this.update_value_label ();
        }

        private void update_value_label ()
        {
            if (this._adjustment != null) {
                var seconds = (int) Math.round (this._adjustment.value).clamp (0, int.MAX);

                this.value_label.label = Pomodoro.format_time (seconds);
            }
        }

        private void on_value_changed ()
        {
            this.update_value_label ();
        }

        public override void dispose ()
        {
            if (this._adjustment != null) {
                this._adjustment.disconnect (this.value_changed_id);
                this.value_changed_id = 0;
            }

            this._adjustment = null;

            base.dispose ();
        }
    }
}
