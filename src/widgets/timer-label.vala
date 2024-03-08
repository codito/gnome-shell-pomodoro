namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/timer-label.ui")]
    public class TimerLabel : Gtk.Widget, Gtk.Buildable
    {
        private const uint   BLINK_DURATION = 1000;
        private const double BLINK_FADE_VALUE = 0.2;
        private const uint   FADE_IN_DURATION = 500;
        private const uint   FADE_OUT_DURATION = 500;

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

        public bool placeholder_has_hours {
            get {
                return this._placeholder_has_hours;
            }
            set {
                if (value == this._placeholder_has_hours) {
                    return;
                }

                this._placeholder_has_hours = value;
                this.placeholder_hours_label.visible = value;
                this.placeholder_hours_separator_label.visible = value;

                this.update_css_classes ();
                this.queue_resize ();
            }
        }

        [GtkChild]
        private unowned Gtk.Box                 placeholder_box;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_hours_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_hours_separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_minutes_separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_seconds_label;
        [GtkChild]
        private unowned Gtk.Box                 box;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel hours_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel hours_separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel minutes_separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel seconds_label;

        private Pomodoro.Timer          _timer;
        private ulong                   timer_state_changed_id = 0;
        private ulong                   timer_tick_id = 0;
        private Adw.TimedAnimation?     crossfade_animation;
        private Adw.TimedAnimation?     blink_animation;
        private Adw.TimedAnimation?     hours_animation;
        private double                  reference_width_lower = 0.0;
        private double                  reference_width_upper = 0.0;
        private double                  reference_height = 0.0;
        private double                  reference_baseline = 0.0;
        private bool                    faded_in = false;
        private bool                    _placeholder_has_hours = false;
        private bool                    has_hours = false;
        private double                  scale = 1.0;


        static construct
        {
            set_css_name ("timerlabel");
        }

        construct
        {
            this._timer = Pomodoro.Timer.get_default ();

            this.set_default_direction_ltr ();
        }

        private void set_default_direction_ltr ()
        {
            this.placeholder_box.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_hours_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_hours_separator_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_minutes_separator_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_seconds_label.set_direction (Gtk.TextDirection.LTR);

            this.box.set_direction (Gtk.TextDirection.LTR);
            this.hours_label.set_direction (Gtk.TextDirection.LTR);
            this.hours_separator_label.set_direction (Gtk.TextDirection.LTR);
            this.minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.minutes_separator_label.set_direction (Gtk.TextDirection.LTR);
            this.seconds_label.set_direction (Gtk.TextDirection.LTR);
        }

        private double get_crossfade_progress ()
        {
            if (this.crossfade_animation != null) {
                return this.crossfade_animation.value;
            }

            return this.faded_in ? 1.0 : 0.0;
        }

        private void update_children_scale ()
        {
            this.placeholder_hours_label.scale = this.scale;
            this.placeholder_hours_separator_label.scale = this.scale;
            this.placeholder_minutes_label.scale = this.scale;
            this.placeholder_minutes_separator_label.scale = this.scale;
            this.placeholder_seconds_label.scale = this.scale;

            this.hours_label.scale = this.scale;
            this.hours_separator_label.scale = this.scale;
            this.minutes_label.scale = this.scale;
            this.minutes_separator_label.scale = this.scale;
            this.seconds_label.scale = this.scale;
        }

        private void stop_hours_animation ()
        {
            if (this.hours_animation != null) {
                this.hours_animation.pause ();
                this.hours_animation = null;
            }
        }

        /**
         * TODO: hours animation is not smooth.
         *
         * When animating labels scale the labels are jittery. It's smoother to keep labels at constant scale during
         * animation, but during snapshot children are pixelated. Either we could render glyphs directly in the
         * snapshot, or render children onto a texture to have more interpolation options.
         */
        private void start_hours_animation ()
        {
            var has_hours = this.get_has_hours ();
            var progress = !has_hours ? 1.0 : 0.0;  // assume previously it was reverse

            if (this.hours_animation != null)
            {
                progress = this.hours_animation.value;

                this.hours_animation.pause ();
                this.hours_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_resize);

            this.hours_animation = new Adw.TimedAnimation (this,
                                                           progress,
                                                           has_hours ? 1.0 : 0.0,
                                                           300,
                                                           animation_target);
            this.hours_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.hours_animation.done.connect (this.stop_hours_animation);
            this.hours_animation.play ();
        }

        private void stop_crossfade_animation ()
        {
            if (this.crossfade_animation != null) {
                this.crossfade_animation.pause ();
                this.crossfade_animation = null;
            }

            this.placeholder_box.set_child_visible (!this.faded_in);
            this.box.set_child_visible (this.faded_in);

            this.queue_allocate ();
        }

        private void fade_in ()
        {
            var crossfade_progress = this.get_crossfade_progress ();

            if (this.faded_in) {
                return;
            }

            if (this.crossfade_animation != null) {
                this.crossfade_animation.pause ();
                this.crossfade_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

            this.crossfade_animation = new Adw.TimedAnimation (this,
                                                               crossfade_progress,
                                                               1.0,
                                                               FADE_IN_DURATION,
                                                               animation_target);
            this.crossfade_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.crossfade_animation.done.connect (this.stop_crossfade_animation);
            this.crossfade_animation.play ();

            this.placeholder_box.set_child_visible (true);
            this.box.set_child_visible (true);
            this.box.opacity = 1.0;

            if (this.has_hours != this._placeholder_has_hours && this.hours_animation == null) {
                this.start_hours_animation ();
            }

            this.faded_in = true;
        }

        private void fade_out ()
        {
            var crossfade_progress = this.get_crossfade_progress ();

            if (!this.faded_in) {
                return;
            }

            if (this.crossfade_animation != null) {
                this.crossfade_animation.pause ();
                this.crossfade_animation = null;
            }

            if (this.blink_animation != null) {
                this.blink_animation.pause ();
                this.blink_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

            this.crossfade_animation = new Adw.TimedAnimation (this,
                                                               crossfade_progress,
                                                               0.0,
                                                               FADE_OUT_DURATION,
                                                               animation_target);
            this.crossfade_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            this.crossfade_animation.done.connect (this.stop_crossfade_animation);
            this.crossfade_animation.play ();

            this.placeholder_box.set_child_visible (true);
            this.box.set_child_visible (true);

            if (this.has_hours != this._placeholder_has_hours && this.hours_animation == null) {
                this.start_hours_animation ();
            }

            this.faded_in = false;
        }

        private void update_css_classes ()
        {
            if (this._placeholder_has_hours) {
                this.placeholder_box.add_css_class ("with-hours");
            }
            else {
                this.placeholder_box.remove_css_class ("with-hours");
            }

            if (this.has_hours) {
                this.box.add_css_class ("with-hours");
            }
            else {
                this.box.remove_css_class ("with-hours");
            }
        }

        private void update_remaining_time (int64 timestamp)
        {
            var remaining = this._timer.calculate_remaining (timestamp);
            var remaining_uint = Pomodoro.Timestamp.to_seconds_uint (remaining);
            var has_hours = remaining_uint >= 3600;

            if (this.has_hours != has_hours)
            {
                this.hours_label.visible = has_hours;
                this.hours_separator_label.visible = has_hours;
                this.has_hours = has_hours;

                this.update_css_classes ();

                if (this.faded_in) {
                    this.start_hours_animation ();
                }
            }

            if (has_hours)
            {
                this.hours_label.text = (remaining_uint / 3600).to_string ();

                remaining_uint = remaining_uint % 3600;
            }

            this.minutes_label.text = "%02u".printf (remaining_uint / 60);
            this.seconds_label.text = "%02u".printf (remaining_uint % 60);
        }

        private void stop_blinking_animation ()
        {
            if (this.blink_animation == null) {
                return;
            }

            this.blink_animation.pause ();
            this.blink_animation = null;

            // Animate opacity back to a baseline value.
            if (this.get_mapped () && this.box.opacity != 1.0)
            {
                var animation_target = new Adw.PropertyAnimationTarget (this.box, "opacity");
                this.blink_animation = new Adw.TimedAnimation (this.box,
                                                               this.box.opacity,
                                                               1.0,
                                                               FADE_IN_DURATION,
                                                               animation_target);
                this.blink_animation.easing = Adw.Easing.EASE_OUT_QUAD;
                this.blink_animation.follow_enable_animations_setting = false;
                this.blink_animation.done.connect (this.stop_blinking_animation);
                this.blink_animation.play ();
            }
            else {
                this.box.opacity = 1.0;
            }
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
            this.blink_animation = new Adw.TimedAnimation (this.box,
                                                           this.box.opacity,
                                                           BLINK_FADE_VALUE,
                                                           BLINK_DURATION,
                                                           animation_target);
            this.blink_animation.alternate = this.box.opacity == 1.0;
            this.blink_animation.follow_enable_animations_setting = false;

            if (this.blink_animation.value_from <= BLINK_FADE_VALUE) {
                this.blink_animation.value_to = 1.0;
            }

            if (this.blink_animation.alternate) {
                this.blink_animation.repeat_count = uint.MAX;
                this.blink_animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            }
            else {
                this.blink_animation.easing = Adw.Easing.EASE_OUT_QUAD;
                this.blink_animation.done.connect (this.start_blinking_animation);
            }

            this.blink_animation.play ();
        }

        private void connect_signals ()
        {
            if (this.timer_tick_id == 0) {
                this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);
            }

            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this._timer.state_changed.connect_after (this.on_timer_state_changed);
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
            var timestamp = this._timer.get_last_tick_time ();

            if (this._timer.user_data != null)
            {
                if (this._timer.is_paused () || this._timer.is_finished () || !this._timer.is_started ()) {
                    this.start_blinking_animation ();
                }
                else {
                    this.stop_blinking_animation ();
                }

                // Prevent from displaying 00:00 while stopping the timer.
                this.update_remaining_time (timestamp);

                this.fade_in ();
            }
            else {
                this.fade_out ();
            }

            if (this.get_mapped ()) {
                this.queue_resize ();
            }
        }

        /**
         * To estimate font scale we need to measure layout at reference scale.
         */
        private void ensure_reference_size ()
        {
            if (this.reference_width_lower == 0.0)
            {
                var layout = this.create_pango_layout ("00:00");
                var layout_width = 0;
                var layout_height = 0;

                layout.get_size (out layout_width, out layout_height);
                this.reference_width_lower = (double) layout_width / (double) Pango.SCALE;
                this.reference_height = (double) layout_height / (double) Pango.SCALE;
                this.reference_baseline = (double) layout.get_baseline () / (double) Pango.SCALE;

                layout.set_text ("0:00:00", 7);
                layout.get_size (out layout_width, out layout_height);
                this.reference_width_upper = (double) layout_width / (double) Pango.SCALE;
            }
        }

        private void invalidate_reference_size ()
        {
            this.reference_width_lower = 0.0;
            this.reference_width_upper = 0.0;
            this.reference_height = 0.0;
            this.reference_baseline = 0.0;
        }

        private bool get_has_hours ()
        {
            return this.timer.is_started () ? this.has_hours : this._placeholder_has_hours;
        }

        private double get_reference_width ()
        {
            if (this.hours_animation != null)
            {
                return Adw.lerp (this.reference_width_lower,
                                 this.reference_width_upper,
                                 this.hours_animation.value);
            }

            return this.faded_in
                ? (double) (this.has_hours ? this.reference_width_upper : this.reference_width_lower)
                : (double) (this._placeholder_has_hours ? this.reference_width_upper : this.reference_width_lower);
        }

        // public override void css_changed (Gtk.CssStyleChange change)
        // {
        //     base.css_changed (change);
        //
        //     this.invalidate_reference_size ();  // NOTE: this is triggered on unfocus
        // }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        /**
         * Estimate size.
         *
         * Interpolate between two children and with-hours / without-hours.
         */
        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            this.ensure_reference_size ();

            var reference_width = this.get_reference_width ();
            var reference_height = this.reference_height;
            var reference_baseline = this.reference_baseline;
            var scale = 1.0;

            if (for_size != -1 && this.halign == Gtk.Align.FILL) {
                scale = orientation == Gtk.Orientation.HORIZONTAL
                    ? (double) for_size / reference_height
                    : (double) for_size / reference_width;
            }

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                natural = (int) Math.round (scale * reference_width);
                natural_baseline = -1;
            }
            else {
                natural = (int) Math.round (scale * reference_height);
                natural_baseline = (int) Math.round (scale * reference_baseline);
            }

            minimum = natural;
            minimum_baseline = natural_baseline;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var placeholder_allocation = Gtk.Allocation ();
            var allocation             = Gtk.Allocation ();

            this.ensure_reference_size ();

            var scale = this.halign == Gtk.Align.FILL
                ? (double) width / this.get_reference_width ()
                : 1.0;

            if (this.scale != scale)
            {
                this.scale = scale;

                this.update_children_scale ();
            }

            this.placeholder_box.measure (
                              Gtk.Orientation.VERTICAL,
                              -1,
                              null,
                              out placeholder_allocation.height,
                              null,
                              null);
            this.placeholder_box.measure (
                              Gtk.Orientation.HORIZONTAL,
                              -1,
                              null,
                              out placeholder_allocation.width,
                              null,
                              null);
            this.box.measure (Gtk.Orientation.VERTICAL,
                              -1,
                              null,
                              out allocation.height,
                              null,
                              null);
            this.box.measure (Gtk.Orientation.HORIZONTAL,
                              -1,
                              null,
                              out allocation.width,
                              null,
                              null);

            switch (this.halign)
            {
                case Gtk.Align.START:
                    placeholder_allocation.x = 0;
                    allocation.x = 0;
                    break;

                case Gtk.Align.END:
                    placeholder_allocation.x = width - placeholder_allocation.width;
                    allocation.x = width - allocation.width;
                    break;

                case Gtk.Align.CENTER:
                case Gtk.Align.FILL:
                    placeholder_allocation.x = (width - placeholder_allocation.width) / 2;
                    allocation.x = (width - allocation.width) / 2;
                    break;

                default:
                    assert_not_reached ();
            }

            placeholder_allocation.y = (height - placeholder_allocation.height) / 2;
            allocation.y = (height - allocation.height) / 2;

            this.placeholder_box.allocate_size (placeholder_allocation, baseline);
            this.box.allocate_size (allocation, baseline);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            if (this.crossfade_animation != null)
            {
                snapshot.push_cross_fade (this.crossfade_animation.value);

                this.snapshot_child (this.placeholder_box, snapshot);
                snapshot.pop ();

                this.snapshot_child (this.box, snapshot);
                snapshot.pop ();
            }
            else {
                if (!this.faded_in) {
                    this.snapshot_child (this.placeholder_box, snapshot);
                }
                else {
                    this.snapshot_child (this.box, snapshot);
                }
            }
        }

        public override void map ()
        {
            this.on_timer_state_changed (this._timer.state, this._timer.state);
            this.connect_signals ();

            base.map ();

            if (this._timer.user_data != null && (
                this._timer.is_paused () || this._timer.is_finished () || !this._timer.is_started ()))
            {
                this.start_blinking_animation ();
            }
        }

        public override void unmap ()
        {
            this.disconnect_signals ();
            this.stop_blinking_animation ();
            this.stop_crossfade_animation ();
            this.stop_hours_animation ();

            base.unmap ();
        }

        public override void unroot ()
        {
            base.unroot ();

            this.invalidate_reference_size ();
        }

        public override void dispose ()
        {
            this.placeholder_box.unparent ();
            this.box.unparent ();

            this._timer = null;

            base.dispose ();
        }
    }
}
