namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/timer-label.ui")]
    public class TimerLabel : Gtk.Widget, Gtk.Buildable
    {
        private const uint BLINK_DURATION = 1000;
        private const double BLINK_FADE_VALUE = 0.2;

        public unowned Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            set {
                if (value == this._timer) {
                    return;
                }

                this.disconnect_signals ();

                this._timer = value;

                if (this.get_mapped ()) {
                    this.connect_signals ();
                }
            }
        }

        [GtkChild]
        private unowned Gtk.Stack               stack;
        [GtkChild]
        private unowned Gtk.Box                 box;
        [GtkChild]
        private unowned Gtk.Box                 placeholder_box;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_seconds_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel seconds_label;

        private Pomodoro.Timer          _timer;
        private ulong                   timer_state_changed_id = 0;
        private ulong                   timer_tick_id = 0;
        private Adw.TimedAnimation?     blink_animation;
        private Pango.Layout?           reference_layout;
        private int                     reference_width;
        private int                     reference_height;
        private int                     reference_baseline;


        static construct
        {
            set_css_name ("timerlabel");
        }

        construct
        {
            this._timer = Pomodoro.Timer.get_default ();

            this.bind_property ("halign", this.stack, "halign", GLib.BindingFlags.SYNC_CREATE);
            this.bind_property ("valign", this.stack, "valign", GLib.BindingFlags.SYNC_CREATE);

            this.set_default_direction_ltr ();
        }

        private void set_default_direction_ltr ()
        {
            this.placeholder_box.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_separator_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_seconds_label.set_direction (Gtk.TextDirection.LTR);

            this.box.set_direction (Gtk.TextDirection.LTR);
            this.minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.separator_label.set_direction (Gtk.TextDirection.LTR);
            this.seconds_label.set_direction (Gtk.TextDirection.LTR);
        }

        private void set_scale_factor (double scale)
        {
            this.placeholder_minutes_label.scale = scale;
            this.placeholder_separator_label.scale = scale;
            this.placeholder_seconds_label.scale = scale;

            this.minutes_label.scale = scale;
            this.separator_label.scale = scale;
            this.seconds_label.scale = scale;
        }

        private void update_visible_child ()
        {
            if (this._timer.is_started ())
            {
                if (this._timer.is_paused () || this._timer.is_finished ()) {
                    this.start_blinking_animation ();
                }
                else {
                    this.stop_blinking_animation ();
                }

                this.stack.visible_child_name = "running";
            }
            else {
                this.stack.visible_child_name = "stopped";
            }
        }

        private void update_remaining_time (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            var remaining = this._timer.calculate_remaining (timestamp);
            var remaining_uint = Pomodoro.Timestamp.to_seconds_uint (remaining);
            var minutes_uint = remaining_uint / 60;
            var seconds_uint = remaining_uint % 60;

            // TODO: hours

            this.minutes_label.text = "%02u".printf (minutes_uint);
            this.seconds_label.text = "%02u".printf (seconds_uint);
        }

        private void start_blinking_animation ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            if (this.blink_animation != null &&
                this.blink_animation.alternate &&
                this.blink_animation.state == Adw.AnimationState.PLAYING)
            {
                return;
            }

            if (this.blink_animation != null) {
                this.blink_animation.pause ();
                this.blink_animation = null;
            }

            var animation_target = new Adw.PropertyAnimationTarget (this.box, "opacity");
            var animation = new Adw.TimedAnimation (this.box,
                                                    this.box.opacity, BLINK_FADE_VALUE, BLINK_DURATION,
                                                    animation_target);
            animation.alternate = this.box.opacity == 1.0;
            animation.follow_enable_animations_setting = false;

            if (animation.value_from <= BLINK_FADE_VALUE) {
                animation.value_to = 1.0;
            }

            if (animation.alternate) {
                animation.repeat_count = uint.MAX;
                animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            }
            else {
                animation.easing = Adw.Easing.EASE_OUT_QUAD;
                animation.done.connect (this.start_blinking_animation);
            }

            this.blink_animation = animation;
            this.blink_animation.play ();
        }

        private void stop_blinking_animation ()
        {
            if (this.blink_animation == null) {
                return;
            }

            if (this.get_mapped () && this.box.opacity != 1.0)
            {
                var animation_target = new Adw.PropertyAnimationTarget (this.box, "opacity");
                var animation = new Adw.TimedAnimation (this.box,
                                                        this.box.opacity, 1.0, 500,
                                                        animation_target);
                animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
                animation.follow_enable_animations_setting = false;

                this.blink_animation.reset ();
                this.blink_animation = animation;
                this.blink_animation.play ();
            }
            else {
                this.blink_animation.reset ();
                this.box.opacity = 1.0;
            }
        }

        private void connect_signals ()
        {
            if (this.timer_tick_id == 0) {
                this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);
            }

            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_tick_id != 0) {
                this._timer.disconnect (this.timer_tick_id);
                this.timer_tick_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        private void on_timer_tick (int64 timestamp)
        {
            this.update_remaining_time (timestamp);
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            // Prevent from displaying 00:00 while stopping the timer.
            if (this._timer.is_started ()) {
                this.update_remaining_time (timestamp);
            }

            this.update_visible_child ();
        }

        private void ensure_reference_layout ()
        {
            if (this.reference_layout == null)
            {
                this.reference_layout = this.minutes_label.create_pango_layout_with_scale ("00:00", 1.0);
                this.reference_layout.get_pixel_size (out this.reference_width, out this.reference_height);
                this.reference_baseline = this.reference_layout.get_baseline () / Pango.SCALE;
            }
        }

        private void clear_reference_layout ()
        {
            if (this.reference_layout == null)
            {
                this.reference_layout = null;
                this.reference_width = 0;
                this.reference_height = 0;
                this.reference_baseline = 0;
            }
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            this.clear_reference_layout ();

            base.css_changed (change);
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        /**
         * Estimate label size according to given size.
         */
        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var scale = 1.0;

            this.ensure_reference_layout ();

            if (for_size != -1 && this.halign == Gtk.Align.FILL) {
                scale = orientation == Gtk.Orientation.HORIZONTAL
                    ? (double) for_size / (double) this.reference_height
                    : (double) for_size / (double) this.reference_width;
            }

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                natural = scale != 1.0
                    ? (int) Math.ceil (scale * (double) this.reference_width)
                    : this.reference_width;
                natural_baseline = -1;
            }
            else {
                natural = scale != 1.0
                    ? (int) Math.ceil (scale * (double) this.reference_height)
                    : this.reference_height;
                natural_baseline = this.reference_baseline;
            }

            minimum = natural;
            minimum_baseline = natural_baseline;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var child = this.get_first_child ();
            var allocation = Gtk.Allocation () {
                x = 0,
                y = 0,
                width = width,
                height = height
            };

            if (this.halign == Gtk.Align.FILL)
            {
                var scale = double.min ((double) width / (double) this.reference_width,
                                        (double) height / (double) this.reference_height);

                this.set_scale_factor (scale);
            }

            child.allocate_size (allocation, baseline);
        }

        public override void map ()
        {
            this.update_remaining_time ();
            this.update_visible_child ();

            this.connect_signals ();

            base.map ();

            if (this._timer.is_paused () || this._timer.is_finished ()) {
                this.start_blinking_animation ();
            }
        }

        public override void unmap ()
        {
            this.disconnect_signals ();
            this.stop_blinking_animation ();

            base.unmap ();
        }

        public override void realize ()
        {
            this.set_direction (Gtk.TextDirection.LTR);

            base.realize ();
        }

        public override void unroot ()
        {
            base.unroot ();

            this.clear_reference_layout ();
        }

        public override void dispose ()
        {
            this.disconnect_signals ();
            this.stop_blinking_animation ();

            base.dispose ();
        }
    }
}
