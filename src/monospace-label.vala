namespace Pomodoro
{
    private void get_glyph_size (Pango.Layout layout,
                                 out int     glyph_width,
                                 out int     glyph_height,
                                 out int     glyph_baseline)
    {
        var context = layout.get_context ();
        var metrics = context.get_metrics (null, null);

        glyph_width = int.max (metrics.get_approximate_char_width (),
                               metrics.get_approximate_digit_width ()) / Pango.SCALE;
        glyph_height = metrics.get_height () / Pango.SCALE;
        glyph_baseline = layout.get_baseline () / Pango.SCALE;
    }

    /**
     * Monospace label treats all character as if they are same width, independently of a chosen font.
     * It's meant for a timer label to reduce layout recomputing.
     */
    public class MonospaceLabel : Gtk.Widget
    {
        public string text {
            get {
                return this._text;
            }
            set {
                if (this._text != value) {
                    var text_length_changes = this._text == null || this._text.length != value.length;

                    this._text = value;

                    this.layout.set_text (this._text, -1);

                    if (text_length_changes) {
                        this.queue_resize ();
                    }
                    else {
                        this.queue_draw ();
                    }
                }
            }
        }

        public float xalign {
            get {
                return this._xalign;
            }
            set {
                this._xalign = value;
            }
        }

        public float yalign {
            get {
                return this._yalign;
            }
            set {
                this._yalign = value;
            }
        }

        private string _text;
        private float _xalign = 0.5f;
        private float _yalign = 0.5f;
        private int glyph_width;
        private int glyph_height;
        private int glyph_baseline;
        private Pango.Layout layout;

        public MonospaceLabel ()
        {
            GLib.Object (css_name: "label");
        }

        construct
        {
            this.text = "";
            this.layout = null;
        }

        private void clear_layout ()
        {
            this.layout = null;
        }

        private void ensure_layout ()
        {
            if (this.layout == null)
            {
                this.layout = this.create_pango_layout (this.text);

                get_glyph_size (this.layout,
                                out this.glyph_width,
                                out this.glyph_height,
                                out this.glyph_baseline);
            }
        }

        private void get_layout_location (out int layout_x,
                                          out int layout_y)
                                          requires (this.layout != null)
        {
            var widget_width = this.get_width ();
            var widget_height = this.get_height ();
            var baseline = this.get_allocated_baseline ();
            var xalign = this.xalign;

            Pango.Rectangle logical;
            this.layout.get_pixel_extents (null, out logical);

            if (this.get_direction () != Gtk.TextDirection.LTR) {
                xalign = 1.0f - xalign;
            }

            layout_x = (int) Math.floor ((xalign * (widget_width - logical.width)) - logical.x);

            if (baseline != -1) {
                // yalign is 0 because we can't support yalign while baseline aligning
                layout_y = baseline - this.glyph_baseline;
            }
            else {
                layout_y = (int) Math.floor ((widget_height - logical.height) * this.yalign);
            }
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            this.clear_layout ();

            base.css_changed (change);
        }

        public virtual void size_allocate (int width,
                                           int height,
                                           int baseline)
        {
            if (this.layout != null) {
                this.layout.set_width (-1);
            }

            // base.size_allocate (width, height, baseline);  // TODO: is it needed?
        }

        public override void measure (Gtk.Orientation orientation,
                                      int for_size,
                                      out int minimum,
                                      out int natural,
                                      out int minimum_baseline,
                                      out int natural_baseline)
        {
            this.ensure_layout ();

            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                minimum = natural = this.text.length * this.glyph_width;
                minimum_baseline = natural_baseline = -1;
            }
            else {
                minimum = natural = this.glyph_height;
                minimum_baseline = natural_baseline = this.glyph_baseline;
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            int layout_x = 0;
            int layout_y = 0;

            if (this.text == "") {
                return;
            }

            this.ensure_layout ();

            var context = this.get_style_context ();

            this.get_layout_location (out layout_x, out layout_y);

            snapshot.render_layout (context, layout_x, layout_y, this.layout);
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

        public override void unroot ()
        {
            base.unroot ();

            this.clear_layout ();
        }
    }
}
