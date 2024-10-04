namespace Pomodoro
{
    public abstract class TimerProgress : Gtk.Widget
    {
        protected const uint   MIN_TIMEOUT_INTERVAL = 50;
        protected const uint   FADE_IN_DURATION = 500;
        protected const uint   FADE_OUT_DURATION = 500;
        protected const float  DEFAULT_LINE_WIDTH = 6.0f;
        protected const int    MIN_WIDTH = 16;
        protected const double EPSILON = 0.00001;

        [CCode (notify = false)]
        public double value {
            get {
                return this._value;
            }
            set {
                if (this._value == value) {
                    return;
                }

                var was_value_set = this._value_set;

                this._value = value;
                this._value_set = true;

                this.notify_property ("value");

                if (!was_value_set) {
                    this.notify_property ("value-set");
                }

                this.queue_draw_highlight ();
            }
        }

        [CCode (notify = false)]
        public bool value_set {
            get {
                return this._value_set;
            }
            set {
                if (this._value_set == value) {
                    return;
                }

                this._value_set = value;

                this.invalidate_value ();

                this.notify_property ("value-set");

                if (!this._value_set) {
                    this._value = this.resolve_value ();
                    this.notify_property ("value");
                }

                this.queue_draw_highlight ();
            }
        }

        [CCode (notify = false)]
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

                this.through.queue_resize ();
                this.highlight.queue_resize ();
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

        protected float               _line_width = DEFAULT_LINE_WIDTH;
        protected double              _value = double.NAN;
        protected bool                _value_set = false;
        protected Pomodoro.Timer      _timer;

        /* Animation for interpolating from `value_animation_start_value` to `_value`. */
        private Adw.TimedAnimation? value_animation;
        private double              value_animation_start_value;

        /* Animation for highlight`s color. */
        private Adw.TimedAnimation? opacity_animation = null;

        /* Preserved value in case we're fading out. */
        private double last_value = double.NAN;

        /* Equivalent with intended opacity. */
        private double last_opacity = 0.0;

        private weak Pomodoro.Gizmo   through;
        private weak Pomodoro.Gizmo   highlight;
        private ulong                 timer_state_changed_id = 0;
        private uint                  timeout_id = 0;
        private uint                  timeout_interval = 0;


        static construct
        {
            set_css_name ("progressbar");
        }

        construct
        {
            this._timer = Pomodoro.Timer.get_default ();

            var through = new Pomodoro.Gizmo (this.measure_child,
                                              null,
                                              this.snapshot_through,
                                              null,
                                              null,
                                              null);
            through.focusable = false;
            through.set_parent (this);

            var highlight = new Pomodoro.Gizmo (this.measure_child,
                                                null,
                                                this.snapshot_highlight_internal,
                                                null,
                                                null,
                                                null);
            highlight.focusable = false;
            highlight.set_parent (this);

            this.highlight = highlight;
            this.through = through;

            this.notify["value"].connect (this.on_value_notify);
        }

        protected virtual uint calculate_timeout_interval ()
        {
            return 0;
        }

        protected virtual uint calculate_animation_duration (double current_value,
                                                             double previous_value)
        {
            return 0;
        }

        protected virtual void measure_child (Pomodoro.Gizmo  gizmo,
                                              Gtk.Orientation orientation,
                                              int             for_size,
                                              out int         minimum,
                                              out int         natural,
                                              out int         minimum_baseline,
                                              out int         natural_baseline)
        {
            minimum = 0;
            natural = 0;
            minimum_baseline = 0;
            natural_baseline = 0;
        }

        protected virtual void snapshot_through (Pomodoro.Gizmo gizmo,
                                                 Gtk.Snapshot   snapshot)
        {
        }

        protected virtual void snapshot_highlight (Pomodoro.Gizmo gizmo,
                                                   Gtk.Snapshot   snapshot,
                                                   double         displayed_value,
                                                   double         opacity)
        {
        }

        protected void snapshot_highlight_internal (Pomodoro.Gizmo gizmo,
                                                    Gtk.Snapshot   snapshot)
        {
            var displayed_value = this._value;
            var opacity         = this.opacity_animation != null
                ? this.opacity_animation.value
                : this.last_opacity;

            if (this.opacity_animation != null && this.opacity_animation.value_to == 0.0) {
                displayed_value = this.last_value;
            }
            else {
                if (!this._value_set) {
                    displayed_value = this.resolve_value ();
                    this._value = displayed_value;
                    this.notify_property ("value");
                }

                if (this.value_animation != null) {
                    displayed_value = Adw.lerp (this.value_animation_start_value,
                                                displayed_value,
                                                this.value_animation.value);
                }

                this.last_value = this._value;
            }

            if (displayed_value.is_nan ()) {
                return;
            }

            this.snapshot_highlight (gizmo, snapshot, displayed_value, opacity);
        }

        private void queue_draw_highlight ()
        {
            this.highlight.queue_draw ();
        }

        private void start_value_animation ()
        {
            if (this.value_animation != null || this.last_value.is_nan ()) {
                return;
            }

            var animation_duration = this.calculate_animation_duration (this._value, this.last_value);

            if (animation_duration > 0)
            {
                var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw_highlight);

                this.value_animation = new Adw.TimedAnimation (this,
                                                               0.0,
                                                               1.0,
                                                               animation_duration,
                                                               animation_target);
                this.value_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                // this.value_animation.set_easing (timer.is_running ()
                //                                  ? Adw.Easing.EASE_IN_OUT_CUBIC
                //                                  : Adw.Easing.EASE_OUT_QUAD);
                this.value_animation.done.connect (this.stop_value_animation);
                this.value_animation.play ();
                this.value_animation_start_value = last_value;
            }
        }

        private void stop_value_animation ()
        {
            if (this.value_animation != null)
            {
                this.value_animation.pause ();
                this.value_animation = null;
                this.value_animation_start_value = double.NAN;
            }
        }

        private void update_value_animation ()
        {
            if (this.get_mapped () && this.opacity_animation == null) {
                this.start_value_animation ();
            }
            else {
                this.stop_value_animation ();
            }
        }

        private void stop_opacity_animation ()
        {
            if (this.opacity_animation != null)
            {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }
        }

        private void fade_in ()
        {
            var last_opacity = this.last_opacity;

            if (this.opacity_animation != null && this.opacity_animation.value_to == 1.0) {
                return;
            }

            if (last_opacity == 1.0) {
                return;
            }

            if (this.opacity_animation != null) {
                last_opacity = this.opacity_animation.value;
                this.stop_opacity_animation ();
            }

            if (this.get_mapped ()) {
                var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw_highlight);
                this.opacity_animation = new Adw.TimedAnimation (this,
                                                                 last_opacity,
                                                                 1.0,
                                                                 FADE_IN_DURATION,
                                                                 animation_target);
                this.opacity_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                this.opacity_animation.done.connect (this.stop_opacity_animation);
                this.opacity_animation.play ();
            }

            this.last_opacity = 1.0;
        }

        private void fade_out ()
        {
            var last_opacity = this.last_opacity;

            if (this.opacity_animation != null && this.opacity_animation.value_to == 0.0) {
                return;
            }

            if (this.last_opacity == 0.0) {
                return;
            }

            if (this.opacity_animation != null) {
                last_opacity = this.opacity_animation.value;
                this.stop_opacity_animation ();
            }

            if (this.get_mapped ()) {
                var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw_highlight);
                this.opacity_animation = new Adw.TimedAnimation (this,
                                                                 last_opacity,
                                                                 0.0,
                                                                 FADE_OUT_DURATION,
                                                                 animation_target);
                this.opacity_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
                this.opacity_animation.done.connect (this.stop_opacity_animation);
                this.opacity_animation.play ();
            }

            this.last_opacity = 0.0;
        }

        private void on_value_notify ()
        {
            if (this._value.is_nan ()) {
                this.fade_out ();
            }
            else {
                this.fade_in ();
            }

            this.update_value_animation ();
        }

        protected double resolve_value ()
        {
            var timestamp = this._timer.is_running ()
                ? this._timer.get_current_time (this.get_frame_clock ().get_frame_time ())
                : this._timer.get_last_state_changed_time ();

            return this._timer.is_started ()
                ? this._timer.calculate_progress (timestamp)
                : double.NAN;
        }

        private void invalidate_value ()
        {
            if (!this._value_set) {
                this._value = this.resolve_value ();
                this.notify_property ("value");
            }

            this.queue_draw_highlight ();
        }

        private void start_timeout ()
        {
            var timeout_interval = uint.max (this.calculate_timeout_interval (), MIN_TIMEOUT_INTERVAL);

            if (this.timeout_interval != timeout_interval) {
                this.timeout_interval = timeout_interval;
                this.stop_timeout ();
            }

            if (this.timeout_id == 0 && this.timeout_interval > 0) {
                this.timeout_id = GLib.Timeout.add (this.timeout_interval, () => {
                    this.invalidate_value ();

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

            this.invalidate_value ();
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

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var minimum_for_size = 0;

            this.through.measure (get_opposite_orientation (orientation),
                                  -1,
                                  out minimum_for_size,
                                  null,
                                  null,
                                  null);
            this.through.measure (orientation,
                                  int.max (minimum_for_size, for_size),
                                  out minimum,
                                  out natural,
                                  null,
                                  null);

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            this.through.allocate (width, height, baseline, null);
            this.highlight.allocate (width, height, baseline, null);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.through, snapshot);
            this.snapshot_child (this.highlight, snapshot);
        }

        public override void map ()
        {
            this.last_value = double.NAN;

            base.map ();

            this.connect_signals ();
        }

        public override void unmap ()
        {
            this.disconnect_signals ();
            this.stop_value_animation ();
            this.stop_opacity_animation ();

            base.unmap ();
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
            this.stop_value_animation ();
            this.stop_opacity_animation ();

            base.dispose ();
        }
    }


    public class TimerProgressBar : Pomodoro.TimerProgress
    {
        public TimerProgressBar ()
        {
            GLib.Object (
                can_focus: false
            );
        }

        protected override uint calculate_timeout_interval ()
                                                       requires (this._timer != null)
        {
            var length = (int64) this.get_width ();

            return length > 0
                ? Pomodoro.Timestamp.to_milliseconds_uint (this._timer.duration / (2 * length))
                : 0;
        }

        protected override uint calculate_animation_duration (double current_value,
                                                              double previous_value)
        {
            var value_diff = ((current_value.is_nan () ? 0.0 : current_value) - previous_value).abs ();

            return value_diff >= 0.01
                ? (uint) (Math.sqrt (value_diff) * 300.0)
                : 0;
        }

        protected override void measure_child (Pomodoro.Gizmo  gizmo,
                                               Gtk.Orientation orientation,
                                               int             for_size,
                                               out int         minimum,
                                               out int         natural,
                                               out int         minimum_baseline,
                                               out int         natural_baseline)
        {
            var line_width = (int) Math.ceilf (this.line_width);

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = int.max (line_width, MIN_WIDTH);
                natural = minimum;
            }
            else {
                minimum = line_width;
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        protected override void snapshot_through (Pomodoro.Gizmo gizmo,
                                                  Gtk.Snapshot   snapshot)
        {
            var style_context = gizmo.get_style_context ();
            var width         = (float) gizmo.get_width ();
            var bounds        = Graphene.Rect ();
            var outline       = Gsk.RoundedRect ();
            var line_width    = this._line_width;

            Gdk.RGBA color;
            style_context.lookup_color ("unfocused_borders", out color);

            bounds.init (0.0f,
                         0.0f,
                         width,
                         line_width);
            outline.init_from_rect (bounds, 0.5f * line_width);

            snapshot.push_rounded_clip (outline);
            snapshot.append_color (color, bounds);
            snapshot.pop ();
        }

        protected override void snapshot_highlight (Pomodoro.Gizmo gizmo,
                                                    Gtk.Snapshot   snapshot,
                                                    double         displayed_value,
                                                    double         opacity)
        {
            if (displayed_value <= EPSILON) {
                return;
            }

            var width           = (float) gizmo.get_width ();
            var style_context   = gizmo.get_style_context ();
            var color           = style_context.get_color ();
            var line_width      = this._line_width;
            var bounds          = Graphene.Rect ();
            var outline         = Gsk.RoundedRect ();

            Gdk.RGBA background_color;
            style_context.lookup_color ("theme_bg_color", out background_color);
            color = blend_colors (background_color, color);
            color.alpha *= (float) opacity;

            var highlight_bounds  = Graphene.Rect ();
            var highlight_outline = Gsk.RoundedRect ();
            var highlight_x = 0.0f;
            var highlight_width = width * (float) displayed_value.clamp (0.0, 1.0);

            if (highlight_width < line_width)
            {
                highlight_x = highlight_width - line_width;

                bounds.init (0.0f, 0.0f, width, line_width);
                outline.init_from_rect (bounds, 0.5f * line_width);
                snapshot.push_rounded_clip (outline);

                highlight_bounds.init (this.get_direction () == Gtk.TextDirection.RTL
                                       ? width - highlight_width - highlight_x : highlight_x,
                                       0.0f,
                                       line_width,
                                       line_width);
                highlight_outline.init_from_rect (highlight_bounds, 0.5f * line_width);

                snapshot.push_rounded_clip (highlight_outline);
                snapshot.append_color (color, highlight_bounds);
                snapshot.pop ();
                snapshot.pop ();
            }
            else {
                highlight_bounds.init (this.get_direction () == Gtk.TextDirection.RTL
                                       ? width - highlight_width : 0.0f,
                                       0.0f,
                                       highlight_width,
                                       line_width);
                highlight_outline.init_from_rect (highlight_bounds, 0.5f * line_width);

                snapshot.push_rounded_clip (highlight_outline);
                snapshot.append_color (color, highlight_bounds);
                snapshot.pop ();
            }
        }
    }


    public class TimerProgressRing : Pomodoro.TimerProgress
    {
        private float  radius;
        private double cap_radius;
        private double cap_angle;


        public TimerProgressRing ()
        {
            GLib.Object (
                can_focus: false
            );
        }

        protected override uint calculate_timeout_interval ()
                                                            requires (this._timer != null)
        {
            var length = (int64) Math.ceil (2.0 * Math.PI * double.min (this.get_width (), this.get_height ()));

            return length > 0
                ? Pomodoro.Timestamp.to_milliseconds_uint (this._timer.duration / (2 * length))
                : 0;
        }

        protected override uint calculate_animation_duration (double current_value,
                                                              double previous_value)
        {
            var value_diff = ((current_value.is_nan () ? 0.0 : current_value) - previous_value).abs ();

            return value_diff >= 0.01
                ? (uint) (Math.sqrt (value_diff) * 600.0)
                : 0;
        }

        protected override void measure_child (Pomodoro.Gizmo  gizmo,
                                               Gtk.Orientation orientation,
                                               int             for_size,
                                               out int         minimum,
                                               out int         natural,
                                               out int         minimum_baseline,
                                               out int         natural_baseline)
        {
            minimum          = int.max (for_size, MIN_WIDTH);
            natural          = minimum;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        protected override void snapshot_through (Pomodoro.Gizmo gizmo,
                                                  Gtk.Snapshot   snapshot)
        {
            var style_context = gizmo.get_style_context ();
            var width         = (float) gizmo.get_width ();
            var height        = (float) gizmo.get_height ();
            var radius        = float.min (width, height) / 2.0f;
            var bounds        = Graphene.Rect ();
            var outline       = Gsk.RoundedRect ();

            Gdk.RGBA color;
            style_context.lookup_color ("unfocused_borders", out color);

            // Ensure that color is non-transparent. Rendering of arcs is glitchy.
            Gdk.RGBA background_color;
            style_context.lookup_color ("theme_bg_color", out background_color);
            color = blend_colors (background_color, color);

            bounds.init (0.5f * width - radius,
                         0.5f * height - radius,
                         2.0f * radius,
                         2.0f * radius);
            outline.init_from_rect (bounds, radius);

            snapshot.append_border (outline,
                                    { this._line_width, this._line_width, this._line_width, this._line_width },
                                    { color, color, color, color });
        }

        protected override void snapshot_highlight (Pomodoro.Gizmo gizmo,
                                                    Gtk.Snapshot   snapshot,
                                                    double         displayed_value,
                                                    double         opacity)
        {
            if (displayed_value >= 1.0 - EPSILON) {
                return;
            }

            var width         = (float) gizmo.get_width ();
            var height        = (float) gizmo.get_height ();
            var radius        = float.min (width, height) / 2.0f;
            var style_context = gizmo.get_style_context ();
            var color         = style_context.get_color ();
            var bounds        = Graphene.Rect ();

            Gdk.RGBA background_color;
            style_context.lookup_color ("theme_bg_color", out background_color);
            color = blend_colors (background_color, color);
            color.alpha *= (float) opacity;

            bounds.init (0.5f * width - radius,
                         0.5f * height - radius,
                         2.0f * radius,
                         2.0f * radius);

            if (this.radius != radius) {
                this.radius = radius;
                this.cap_radius = this._line_width / 2.0;
                this.cap_angle  = Math.atan2 (this.cap_radius, (double) radius);
            }

            var context    = snapshot.append_cairo (bounds);
            var angle_from = - 0.5 * Math.PI - (2.0 * Math.PI + this.cap_angle) * displayed_value.clamp (EPSILON, 1.0);
            var angle_to   = - 0.5 * Math.PI;

            if (angle_from <= angle_to - 2.0 * Math.PI) {
                context.arc (0.5 * width, this.cap_radius, this.cap_radius, 0.0, 2.0 * Math.PI);
                context.clip ();
                angle_to -= this.cap_angle;
            }

            context.set_line_width (this._line_width);
            context.set_line_cap (Cairo.LineCap.ROUND);
            context.set_source_rgba (color.red,
                                     color.green,
                                     color.blue,
                                     color.alpha);
            context.arc_negative (0.5 * width,
                                  0.5 * height,
                                  (double) radius - this.cap_radius,
                                  angle_from,
                                  angle_to);
            context.stroke ();
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            // HACK: Scale line-width according to size.
            var min_size = 300.0;
            var max_size = 450.0;
            var line_width = Adw.lerp (6.0, 8.0, ((double) width - min_size) / (max_size - min_size));

            this.line_width = (float) Math.round (line_width);

            base.size_allocate (width, height, baseline);
        }
    }
}
