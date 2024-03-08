namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/volume-slider.ui")]
    public class VolumeSlider : Gtk.Box
    {
        private const string[] VOLUME_IMAGES = {
            "audio-volume-muted-symbolic",
            "audio-volume-low-symbolic",
            "audio-volume-medium-symbolic",
            "audio-volume-high-symbolic"
        };

        [CCode (notify = false)]
        public double value {
            get {
                return this.adjustment.value;
            }
            set {
                this.adjustment.value = value;
            }
        }

        [GtkChild]
        private unowned Gtk.Image volume_image;
        [GtkChild]
        private unowned Gtk.Adjustment adjustment;

        private double last_volume = 1.0;

        construct
        {
            this.update_volume_image ();
        }

        private void update_volume_image ()
        {
            var value = this.adjustment.value;
            string icon_name;

            if (value == 0.0) {
                icon_name = VOLUME_IMAGES[0];
            }
            else if (value < 0.3) {
                icon_name = VOLUME_IMAGES[1];
            }
            else if (value < 0.7) {
                icon_name = VOLUME_IMAGES[2];
            }
            else {
                icon_name = VOLUME_IMAGES[3];
            }

            this.volume_image.icon_name = icon_name;
        }

        [GtkCallback]
        private void on_mute_button_clicked ()
        {
            if (this.adjustment.value > 0.0) {
                this.last_volume = this.adjustment.value;
                this.adjustment.value = 0.0;
            }
            else {
                this.adjustment.value = this.last_volume > 0.0 ? this.last_volume : 1.0;
            }
        }

        [GtkCallback]
        private void on_adjustment_value_changed ()
        {
            this.update_volume_image ();

            this.notify_property ("value");
        }
    }
}
