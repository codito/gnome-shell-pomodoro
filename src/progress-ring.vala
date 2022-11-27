namespace Pomodoro
{
    public class ProgressRing : Gtk.Widget
    {
        private const uint  FADE_IN_DURATION = 500;
        private const uint  FADE_OUT_DURATION = 500;
        private const float DEFAULT_LINE_WIDTH = 6.0f;

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
                this.queue_draw ();
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

                this._value = value;

                this.notify_property ("value");
                this.highlight.queue_draw ();
            }
        }

        private float               _line_width = DEFAULT_LINE_WIDTH;
        private double              _value = 0.0;
        private Adw.TimedAnimation? fade_animation;

        protected weak Pomodoro.Gizmo through;
        protected weak Pomodoro.Gizmo highlight;

        static construct
        {
            set_css_name ("progressring");
        }

        construct
        {
            var through = new Pomodoro.Gizmo (null,
                                              null,
                                              this.snapshot_through,
                                              null,
                                              null,
                                              null);
            through.focusable = false;
            through.set_parent (this);

            var highlight = new Pomodoro.Gizmo (null,
                                                null,
                                                this.snapshot_highlight,
                                                null,
                                                null,
                                                null);
            highlight.focusable = false;
            highlight.set_parent (this);

            this.highlight = highlight;
            this.through = through;

            this.layout_manager = new Gtk.BinLayout ();
        }

        private void snapshot_through (Pomodoro.Gizmo gizmo,
                                       Gtk.Snapshot   snapshot)
        {
            var style_context = gizmo.get_style_context ();
            var width         = (float) gizmo.get_width ();
            var height        = (float) gizmo.get_height ();
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

        private void snapshot_highlight (Pomodoro.Gizmo gizmo,
                                         Gtk.Snapshot   snapshot)
        {
            var value = this.resolve_value (this.get_frame_clock ().get_frame_time ());

            if (this._value != value) {
                this._value = value;
                this.notify_property ("value");
            }

            if (value.is_nan ()) {
                return;
            }

            var width         = (float) gizmo.get_width ();
            var height        = (float) gizmo.get_height ();
            var style_context = gizmo.get_style_context ();
            var color         = style_context.get_color ();
            var radius        = 0.5f * float.min (width, height);
            var center_x      = 0.5f * width;
            var center_y      = 0.5f * height;
            var line_width    = this._line_width;
            var bounds        = Graphene.Rect ();
            bounds.init (center_x - radius, center_y - radius, 2.0f * radius, 2.0f * radius);

            var angle_from = - 0.5 * Math.PI - 2.0 * Math.PI * value.clamp (0.000001, 1.0);
            var angle_to   = - 0.5 * Math.PI;
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
                                  angle_from,
                                  angle_to);
            context.stroke ();
        }

        protected void fade_in ()
        {
            if (this.fade_animation != null && this.fade_animation.value_to == 1.0) {
                return;
            }

            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw_highlight);
            this.fade_animation = new Adw.TimedAnimation (this,
                                                          0.0,
                                                          1.0,
                                                          FADE_IN_DURATION,
                                                          animation_target);
            this.fade_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.fade_animation.play ();
        }

        protected void fade_out ()
        {
            if (this.fade_animation != null && this.fade_animation.value_to == 0.0) {
                return;
            }

            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw_highlight);
            this.fade_animation = new Adw.TimedAnimation (this,
                                                          1.0,
                                                          0.0,
                                                          FADE_OUT_DURATION,
                                                          animation_target);
            this.fade_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            this.fade_animation.play ();
        }

        protected void queue_draw_highlight ()
        {
            this.highlight.queue_draw ();
        }

        public virtual double resolve_value (int64 monotonic_time)
        {
            return this._value;
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            this.through.allocate (width, height, baseline, null);
            this.highlight.allocate (width, height, baseline, null);
        }

        public void snapshot (Gtk.Snapshot snapshot)
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
    }
}
