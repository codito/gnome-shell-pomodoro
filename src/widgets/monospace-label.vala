namespace Pomodoro
{
    // TODO: rename to NumericLabel
    /**
     * Optimized version of Gtk.Label that doesn't trigger size allocation on text changes.
     * It also simplifies scaling and uses monospace width for digits.
     */
    public class MonospaceLabel : Gtk.Widget
    {
        public string text {
            get {
                return this._text;
            }
            set {
                if (this._text == value) {
                    return;
                }

                var previous_text_length = this._text != null ? this._text.length : 0;

                this._text = value;

                if (this.layout != null && previous_text_length == value.length) {
                    this.layout.set_text (value, value.length);
                    this.queue_draw ();
                }
                else {
                    this.clear_layout ();
                    this.queue_resize ();
                }
            }
        }

        public float xalign {
            get {
                return this._xalign;
            }
            set {
                this._xalign = value;

                this.queue_allocate ();
            }
        }

        public float yalign {
            get {
                return this._yalign;
            }
            set {
                this._yalign = value;

                this.queue_allocate ();
            }
        }

        public double scale {
            get {
                return this._scale;
            }
            set {
                if (this._scale == value) {
                    return;
                }

                this._scale = value;

                this.clear_layout ();
                this.queue_resize ();
            }
        }

        private string        _text = null;
        private float         _xalign = 0.5f;
        private float         _yalign = 0.5f;
        private double        _scale = 1.0;
        private Pango.Layout? layout = null;
        private int           layout_x = 0;
        private int           layout_y = 0;
        private int           layout_width = 0;
        private int           layout_height = 0;
        private int           layout_baseline = -1;


        static construct
        {
            set_css_name ("label");
        }

        construct
        {
            this.accessible_role = Gtk.AccessibleRole.LABEL;
            this._text = "";
            this.layout = null;
        }

        internal Pango.Layout create_pango_layout_with_scale (string text,
                                                              double scale)
        {
            var context = this.create_pango_context ();

            var attributes = new Pango.AttrList ();
            attributes.insert (Pango.attr_scale_new (scale));
            attributes.insert (new Pango.AttrFontFeatures ("tnum"));

            var layout = new Pango.Layout (context);
            layout.set_ellipsize (Pango.EllipsizeMode.NONE);
            layout.set_attributes (attributes);
            layout.set_text (text, text.length);

            return layout;
        }

        private void measure_pango_layout (Pango.Layout layout,
                                           out int      width,
                                           out int      height,
                                           out int      baseline)
        {
            var text = layout.get_text ();
            var is_numeric = int.try_parse (text);

            layout.get_pixel_size (out width, out height);
            baseline = layout.get_baseline () / Pango.SCALE;

            if (is_numeric)
            {
                var reference_text = string.nfill (text.length, '0');
                var reference_layout = layout.copy ();
                reference_layout.set_text (reference_text, reference_text.length);
                reference_layout.get_pixel_size (out width, null);
            }
        }

        private void ensure_layout ()
        {
            if (this.layout == null) {
                this.layout = this.create_pango_layout_with_scale (this._text, this._scale);

                this.measure_pango_layout (this.layout,
                                           out this.layout_width,
                                           out this.layout_height,
                                           out this.layout_baseline);
            }
        }

        private void clear_layout ()
        {
            this.layout = null;
            this.layout_x = 0;
            this.layout_y = 0;
            this.layout_width = 0;
            this.layout_height = 0;
            this.layout_baseline = -1;
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            base.css_changed (change);

            this.clear_layout ();
            this.queue_resize ();
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
            this.ensure_layout ();

            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                minimum = this.layout_width;
                natural = minimum;
                minimum_baseline = -1;
                natural_baseline = -1;
            }
            else {
                minimum = this.layout_height;
                natural = minimum;
                minimum_baseline = this.layout_baseline;
                natural_baseline = this.layout_baseline;
            }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            this.ensure_layout ();

            this.layout_x = (int) Math.floorf ((float)(width - this.layout_width) * this._xalign);
            this.layout_y = baseline != -1
                ? baseline - this.layout_baseline
                : (int) Math.floorf ((float)(height - this.layout_height) * this._yalign);

            if (this.get_direction () == Gtk.TextDirection.RTL) {
                this.layout_x = width - this.layout_x;
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
                                       requires (this.layout != null)
        {
            var origin = Graphene.Point () {
                x = (float) this.layout_x,
                y = (float) this.layout_y
            };

            snapshot.translate (origin);
            snapshot.append_layout (this.layout, this.get_color ());
        }

        public override bool focus (Gtk.DirectionType direction)
        {
            return false;
        }

        public override bool grab_focus ()
        {
            return false;
        }

        public override void unroot ()
        {
            base.unroot ();

            this.clear_layout ();
        }
    }
}
