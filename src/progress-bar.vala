namespace Pomodoro
{
    public enum ProgressBarShape
    {
        BAR = 0,
        RING = 1
    }


    public class ProgressBar : Gtk.Widget
    {
        private const uint  FADE_IN_DURATION = 500;
        private const uint  FADE_OUT_DURATION = 500;
        private const float DEFAULT_LINE_WIDTH = 6.0f;
        private const int   MIN_WIDTH = 16;

        [CCode (notify = false)]
        public Pomodoro.ProgressBarShape shape {
            get {
                return this._shape;
            }
            set {
                if (this._shape == value) {
                    return;
                }

                this._shape = value;

                this.notify_property ("shape");
                this.queue_resize ();
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

        private Pomodoro.ProgressBarShape _shape = Pomodoro.ProgressBarShape.BAR;
        private float                     _line_width = DEFAULT_LINE_WIDTH;
        private double                    _value = double.NAN;
        private bool                      _value_set = false;
        private weak Pomodoro.Gizmo       through;
        private weak Pomodoro.Gizmo       highlight;

        /* Animation for interpolating from `value_animation_start_value` to `_value`. */
        private Adw.TimedAnimation? value_animation;
        private double              value_animation_start_value;

        /* Animation for highlight`s color. */
        private Adw.TimedAnimation? opacity_animation;

        /* Preserved value in case we're fading out. */
        private double last_value = double.NAN;

        /* Equivalent with intended opacity. */
        private double last_opacity = 0.0;

        static construct
        {
            set_css_name ("progressbar");
        }

        construct
        {
            this.layout_manager = new Gtk.BinLayout ();

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
                                                this.snapshot_highlight,
                                                null,
                                                null,
                                                null);
            highlight.focusable = false;
            highlight.set_parent (this);

            this.highlight = highlight;
            this.through = through;

            this.notify["value"].connect (this.on_value_notify);
        }

        public ProgressBar ()
        {
            GLib.Object (
                can_focus: false
            );
        }

        public void measure_child (Pomodoro.Gizmo  gizmo,
                                   Gtk.Orientation orientation,
                                   int             for_size,
                                   out int         minimum,
                                   out int         natural,
                                   out int         minimum_baseline,
                                   out int         natural_baseline)
        {
            switch (this._shape)
            {
                case Pomodoro.ProgressBarShape.BAR:
                    var line_width = (int) Math.ceilf (this.line_width);

                    if (orientation == Gtk.Orientation.HORIZONTAL) {
                        minimum = int.max (line_width, MIN_WIDTH);
                        natural = minimum;
                    }
                    else {
                        minimum = line_width;
                        natural = minimum;
                    }
                    break;

                case Pomodoro.ProgressBarShape.RING:
                    minimum = int.max (for_size, MIN_WIDTH);
                    natural = minimum;
                    break;

                default:
                    assert_not_reached ();
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_through (Pomodoro.Gizmo gizmo,
                                       Gtk.Snapshot   snapshot)
        {
            var style_context = gizmo.get_style_context ();
            var width         = (float) gizmo.get_width ();
            var height        = (float) gizmo.get_height ();
            var bounds        = Graphene.Rect ();
            var outline       = Gsk.RoundedRect ();
            var line_width    = this._line_width;

            Gdk.RGBA color;
            style_context.lookup_color ("unfocused_borders", out color);

            switch (this._shape)
            {
                case Pomodoro.ProgressBarShape.BAR:
                    bounds.init (0.0f,
                                 0.0f,
                                 width,
                                 line_width);
                    outline.init_from_rect (bounds, 0.5f * line_width);

                    snapshot.push_rounded_clip (outline);
                    snapshot.append_color (color, bounds);
                    snapshot.pop ();
                    break;

                case Pomodoro.ProgressBarShape.RING:
                    var radius = 0.5f * float.min (width, height);

                    bounds.init (0.5f * width - radius,
                                 0.5f * height - radius,
                                 2.0f * radius,
                                 2.0f * radius);
                    outline.init_from_rect (bounds, radius);

                    snapshot.append_border (outline,
                                            { line_width, line_width, line_width, line_width },
                                            { color, color, color, color });
                    break;

                default:
                    assert_not_reached ();
            }
        }

        private void snapshot_highlight (Pomodoro.Gizmo gizmo,
                                         Gtk.Snapshot   snapshot)
        {
            var width         = (float) gizmo.get_width ();
            var height        = (float) gizmo.get_height ();
            var style_context = gizmo.get_style_context ();
            var color         = style_context.get_color ();
            var line_width    = this._line_width;
            var bounds        = Graphene.Rect ();

            var displayed_value = this._value;
            var opacity         = this.opacity_animation != null
                ? this.opacity_animation.value
                : this.last_opacity;

            Gdk.RGBA background_color;
            style_context.lookup_color ("theme_bg_color", out background_color);

            color = blend_colors (background_color, color);

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

            color.alpha *= (float) opacity;

            switch (this._shape)
            {
                case Pomodoro.ProgressBarShape.BAR:
                    var outline = Gsk.RoundedRect ();
                    var highlight_width = float.max (width * (float) displayed_value.clamp (0.0, 1.0), line_width);

                    bounds.init (this.get_direction () == Gtk.TextDirection.RTL ? width - highlight_width : 0.0f,
                                 0.0f,
                                 highlight_width,
                                 line_width);
                    outline.init_from_rect (bounds, 0.5f * line_width);

                    snapshot.push_rounded_clip (outline);
                    snapshot.append_color (color, bounds);
                    snapshot.pop ();
                    break;

                case Pomodoro.ProgressBarShape.RING:
                    var radius     = 0.5f * float.min (width, height);
                    var angle_from = - 0.5 * Math.PI - 2.0 * Math.PI * displayed_value.clamp (0.000001, 1.0);
                    var angle_to   = - 0.5 * Math.PI;

                    bounds.init (0.5f * width - radius,
                                 0.5f * height - radius,
                                 2.0f * radius,
                                 2.0f * radius);

                    var context = snapshot.append_cairo (bounds);
                    context.set_line_width (line_width);
                    context.set_line_cap (Cairo.LineCap.ROUND);
                    context.set_source_rgba (color.red,
                                             color.green,
                                             color.blue,
                                             color.alpha);
                    context.arc_negative (0.5f * width,
                                          0.5f * height,
                                          radius - line_width / 2.0,
                                          angle_from,
                                          angle_to);
                    context.stroke ();
                    break;

                default:
                    assert_not_reached ();
            }
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

            var value_diff = ((this._value.is_nan () ? 0.0 : this._value) - this.last_value).abs ();
            if (value_diff < 0.01) {
                return;
            }

            var max_duration = this._shape == Pomodoro.ProgressBarShape.RING ? 600.0 : 300.0;
            var animation_duration = (uint) (Math.sqrt (value_diff) * max_duration);
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

        public void invalidate_value ()
        {
            if (!this._value_set) {
                this._value = this.resolve_value ();
                this.notify_property ("value");
            }

            this.queue_draw_highlight ();
        }

        public virtual double resolve_value ()
        {
            return this._value;
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
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

        public override bool focus (Gtk.DirectionType direction)
        {
            return false;
        }

        public override bool grab_focus ()
        {
            return false;
        }

        public override void unmap ()
        {
            this.stop_value_animation ();
            this.stop_opacity_animation ();

            base.unmap ();

            this.last_value = double.NAN;
        }


        public override void dispose ()
        {
            this.stop_value_animation ();
            this.stop_opacity_animation ();

            base.dispose ();
        }
    }
}
