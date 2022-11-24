namespace Pomodoro
{
    public class TimerProgressBar : Gtk.Widget
    {
        private const uint  FADE_IN_DURATION = 500;
        private const uint  FADE_OUT_DURATION = 500;
        private const float DEFAULT_LINE_WIDTH = 6.0f;

        private class Through : Gtk.Widget
        {
            public float line_width {
                get {
                    return this._line_width;
                }
                set {
                    if (this._line_width == value) {
                        return;
                    }

                    this._line_width = value;

                    this.notify_property ("line-width");
                    this.queue_draw ();
                }
            }

            private float _line_width = DEFAULT_LINE_WIDTH;

            public override Gtk.SizeRequestMode get_request_mode ()
            {
                return Gtk.SizeRequestMode.CONSTANT_SIZE;
            }

            public override bool focus (Gtk.DirectionType direction)
            {
                return false;
            }

            public override bool grab_focus ()
            {
                return false;
            }

            public override void measure (Gtk.Orientation orientation,
                                          int for_size,
                                          out int minimum,
                                          out int natural,
                                          out int minimum_baseline,
                                          out int natural_baseline)
            {
                minimum = 0;
                natural = for_size;
                minimum_baseline = -1;
                natural_baseline = -1;
            }

            public override void snapshot (Gtk.Snapshot snapshot)
            {
                var style_context = this.get_style_context ();
                var width         = (float) this.get_width ();
                var height        = (float) this.get_height ();
                var radius        = 0.5f * float.min (width, height);
                var center_x      = 0.5f * width;
                var center_y      = 0.5f * height;
                var bounds        = Graphene.Rect ();
                var through       = Gsk.RoundedRect ();
                var line_width    = this._line_width;

                Gdk.RGBA color;
                style_context.lookup_color ("unfocused_borders", out color);

                bounds.init (center_x - radius, center_y - radius, 2.0f * radius, 2.0f * radius);
                through.init_from_rect (bounds, radius);

                snapshot.append_border (through,
                                        { line_width, line_width, line_width, line_width },
                                        { color, color, color, color });
            }
        }

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

        public float line_width {
            get {
                return this._line_width;
            }
            set {
                if (this._line_width == value) {
                    return;
                }

                this._line_width = value;

                this.notify_property ("line-width");
                this.queue_draw ();
            }
        }

        private Pomodoro.Timer      _timer;
        private float               _line_width = DEFAULT_LINE_WIDTH;
        private ulong               timer_state_changed_id = 0;
        private uint                timeout_id = 0;
        private uint                timeout_interval = 0;
        private weak Through        through;
        private Adw.TimedAnimation? fade_animation;

        static construct
        {
            set_css_name ("timerprogressbar");
        }

        construct
        {
            this._timer = Pomodoro.Timer.get_default ();

            var through = new Through ();
            through.set_child_visible (true);
            through.set_parent (this);
            through.bind_property ("line-width", this, "line-width", GLib.BindingFlags.SYNC_CREATE);

            this.through = through;
            this.layout_manager = new Gtk.BinLayout ();
        }

        private uint calculate_timeout_interval ()
        {
            var perimeter = (int64) Math.ceil (
                    2.0 * Math.PI * double.min (this.get_width (), this.get_height ()));

            return Pomodoro.Timestamp.to_milliseconds_uint (this._timer.duration / (2 * perimeter));
        }

        private void fade_in ()
        {
            if (this.fade_animation != null && this.fade_animation.value_to == 1.0) {
                return;
            }

            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (() => {
                this.queue_draw ();
            });
            this.fade_animation = new Adw.TimedAnimation (this,
                                                          0.0,
                                                          1.0,
                                                          FADE_IN_DURATION,
                                                          animation_target);
            this.fade_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.fade_animation.play ();
        }

        private void fade_out ()
        {
            if (this.fade_animation != null && this.fade_animation.value_to == 0.0) {
                return;
            }

            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (() => {
                this.queue_draw ();
            });
            this.fade_animation = new Adw.TimedAnimation (this,
                                                          1.0,
                                                          0.0,
                                                          FADE_OUT_DURATION,
                                                          animation_target);
            this.fade_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            this.fade_animation.play ();
        }

        private void start_timeout ()
        {
            var timeout_interval = uint.max (this.calculate_timeout_interval (), 50);

            if (this.timeout_interval != timeout_interval) {
                this.timeout_interval = timeout_interval;
                this.stop_timeout ();
            }

            if (this.timeout_id == 0) {
                this.timeout_id = GLib.Timeout.add (this.timeout_interval, () => {
                    this.queue_draw ();

                    return GLib.Source.CONTINUE;
                });
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.TimerProgressBar.on_timeout");
            }
        }

        private void stop_timeout ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this._timer.is_running ()) {
                this.start_timeout ();
            }
            else {
                this.stop_timeout ();
            }

            if (this._timer.is_started ()) {
                this.fade_in ();
            }
            else {
                this.fade_out ();
            }

            this.queue_draw ();
        }

        private void connect_signals ()
        {
            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
            }

            if (this._timer.is_running ()) {
                this.start_timeout ();
            }
        }

        private void disconnect_signals ()
        {
            this.stop_timeout ();

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        public override void map ()
        {
            base.map ();

            this.connect_signals ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.disconnect_signals ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var timestamp           = this._timer.get_current_time (this.get_frame_clock ().get_frame_time ());
            var progress            = this._timer.calculate_progress (timestamp);
            var progress_angle_from = - 0.5 * Math.PI - 2.0 * Math.PI * progress.clamp (0.000001, 1.0);
            var progress_angle_to   = - 0.5 * Math.PI;

            var width         = (float) this.get_width ();
            var height        = (float) this.get_height ();
            var style_context = this.get_style_context ();
            var color         = style_context.get_color ();
            var radius        = 0.5f * float.min (width, height);
            var center_x      = 0.5f * width;
            var center_y      = 0.5f * height;
            var bounds        = Graphene.Rect ();
            var line_width    = this._line_width;

            bounds.init (center_x - radius, center_y - radius, 2.0f * radius, 2.0f * radius);

            this.snapshot_child (this.through, snapshot);

            if (this._timer.is_started ())
            {
                var fade_value = this.fade_animation != null
                    ? this.fade_animation.value
                    : 1.0;

                var context = snapshot.append_cairo (bounds);
                context.set_line_width (line_width);
                context.set_line_cap (Cairo.LineCap.ROUND);
                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * fade_value);
                context.arc_negative (center_x,
                                      center_y,
                                      radius - line_width / 2.0,
                                      progress_angle_from,
                                      progress_angle_to);
                context.stroke ();
            }
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override bool focus (Gtk.DirectionType direction)
        {
            return false;
        }

        public override bool grab_focus ()
        {
            return false;
        }

        public override void dispose ()
        {
            this.disconnect_signals ();

            base.dispose ();
        }
    }
}
