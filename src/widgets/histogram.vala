namespace Pomodoro
{
    private struct Category
    {
        public string   label;
        public Gdk.RGBA color;
    }


    private struct Bucket
    {
        public string     label;
        public string     tooltip_label;
        // public GLib.Value identity;
    }


    /**
     * Widget for displaying a histogram.
     *
     * A histogram is more general case of a stacked bar chart - it can be used for both.
     */
    public class Histogram : Pomodoro.Chart
    {
        private const int    MIN_BAR_WIDTH = 16;
        private const int    MAX_BAR_WIDTH = 30;
        private const double MIN_BAR_HEIGHT = 2.5;
        private const float  BAR_SPACING = 0.25f;
        private const int    MIN_BAR_SPACING = 2;
        private const float  MAX_EXPANSION = 1.66f;
        private const double EPSILON = 0.00001;

        /**
         * Value that should be visible on the chart.
         */
        public double reference_value {
            get {
                return this._reference_value;
            }
            set {
                if (this._reference_value == value) {
                    return;
                }

                this._reference_value = value;

                this.invalidate_max_value ();
            }
        }

        public bool stacked {
            get {
                return this._stacked;
            }
            set {
                if (this._stacked == value) {
                    return;
                }

                this._stacked = value;

                this.invalidate_max_value ();
            }
        }

        public bool show_empty_bars { get; set; default = false; }

        private double                 _reference_value = 1.0;
        private bool                   _stacked = true;
        private Bucket[]               buckets;
        private Category[]             categories;
        private Pomodoro.Matrix?       data;
        private double                 max_value = 0.0;
        private int                    bar_width;
        private int                    bar_height;
        private int                    bar_radius;
        private bool                   dirty = false;  // it refers to the number of bars, not values drawn
        private int                    tooltip_bucket_index = -1;
        private Gtk.Widget?            tooltip_widget;

        construct
        {
            this.buckets    = {};
            this.categories = {};
        }


        /*
         * Data
         */

        private double calculate_bucket_sum (uint bucket_index)
        {
            var values = this.data.get_vector (0, (int) bucket_index);

            return values != null ? values.sum () : 0.0;
        }

        private double calculate_bucket_max (uint bucket_index)
        {
            var values = this.data.get_vector (0, (int) bucket_index);

            return values != null ? values.max () : double.NAN;
        }

        private double calculate_max_value ()
        {
            var max_value = double.NAN;

            if (this._stacked && this.data.shape[1] > 0U)
            {
                var categories_data = this.data.unstack ();
                var values = categories_data[0].copy ();
                var category_index = 1;

                for (; category_index < categories_data.length; category_index++) {
                    if (!values.add (categories_data[category_index])) {
                        GLib.debug ("Histogram: Unable to calculate max_value");
                    }
                }

                max_value = values.max ();
            }
            else {
                max_value = this.data.max ();
            }

            return double.max (max_value, this._reference_value);
        }

        private void invalidate_max_value ()
        {
            this.max_value = double.NAN;

            this.queue_allocate ();
        }

        private void ensure_data ()
        {
            var bucket_count = this.buckets.length;
            var category_count = this.categories.length;

            if (this.data == null) {
                this.data = new Pomodoro.Matrix (bucket_count, category_count);
            }

            if (this.data.shape[0] != bucket_count ||
                this.data.shape[1] != category_count)
            {
                this.data.resize (bucket_count, category_count);
            }
        }

        // TODO: remove it? it's more suitable for a BarChart
        public uint add_bucket (string     label,
                                GLib.Value identity)
        {
            var bucket_index = this.buckets.length;

            this.buckets += Bucket () {
                label         = label,
                tooltip_label = label,
                // identity      = identity
            };
            this.dirty = true;

            this.queue_allocate ();

            return bucket_index;
        }

        public uint get_buckets_count ()
        {
            return this.buckets.length;
        }

        public uint get_categories_count ()
        {
            return this.categories.length;
        }

        public uint add_category (string label)
        {
            var category_index = this.categories.length;

            this.categories += Category () {
                label = label,
                color = this.get_color ()
            };
            this.dirty = true;

            this.queue_allocate ();

            return category_index;
        }

        public void set_category_label (uint   category_index,
                                        string label)
        {
            if (category_index < this.categories.length)
            {
                this.categories[category_index].label = label;
            }
            else {
                GLib.warning ("Can't set label for category #%u", category_index);
            }
        }

        public void set_category_color (uint     category_index,
                                        Gdk.RGBA color)
        {
            if (category_index < this.categories.length)
            {
                this.categories[category_index].color = color;

                this.queue_draw ();
            }
            else {
                GLib.warning ("Can't set color for category #%u", category_index);
            }

        }

        public void set_tooltip_label (uint   bucket_index,
                                       string label)
        {
            if (bucket_index < this.buckets.length) {
                this.buckets[bucket_index].tooltip_label = label;
            }
            else {
                GLib.warning ("Can't set tooltip_label for bucket #%u", bucket_index);
            }
        }

        public void set_values (uint     bucket_index,
                                double[] values)
        {
            this.ensure_data ();

            var category_index = 0;

            for (; category_index < values.length; category_index++) {
                this.data.@set ((int) bucket_index, category_index, values[category_index]);
            }

            for (; category_index < this.data.shape[1]; category_index++) {
                this.data.@set ((int) bucket_index, category_index, 0.0);
            }

            this.invalidate_max_value ();
        }

        public void set_value (uint   bucket_index,
                               uint   category_index,
                               double value)
        {
            this.ensure_data ();

            this.data.@set ((int) bucket_index, (int) category_index, value);

            this.invalidate_max_value ();
        }

        private inline bool is_bucket_empty (uint bucket_index)
        {
            return this.calculate_bucket_sum (bucket_index) <= EPSILON;
        }

        private uint skip_empty_bucket_index (uint bucket_index)
        {
            while (!this.show_empty_bars &&
                   bucket_index < this.buckets.length &&
                   this.is_bucket_empty (bucket_index))
            {
                bucket_index++;
            }

            return bucket_index;
        }


        /*
         * Bars
         */

        private Gtk.Widget? create_tooltip_widget (uint bucket_index)
        {
            var bucket = this.buckets[bucket_index];
            var category_count = this.categories.length;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 10;
            grid.row_spacing = 5;
            grid.row_homogeneous = true;
            grid.add_css_class ("tooltip-contents");

            var header_label = new Gtk.Label (bucket.tooltip_label);
            header_label.add_css_class ("tooltip-header");
            grid.attach (header_label, 0, 0, 2, 1);

            for (var category_index = category_count - 1; category_index >= 0; category_index--)
            {
                var category = this.categories[category_index];
                var category_value = this.data.@get ((int) bucket_index, category_index);

                var category_label = new Gtk.Label (@"$(category.label):");
                category_label.halign = Gtk.Align.START;
                grid.attach (category_label, 0, 1 + category_index);

                var value_label = new Gtk.Label (this.format_y_value (category_value));
                value_label.halign = Gtk.Align.END;
                grid.attach (value_label, 1, 1 + category_index);
            }

            // TODO: interruptions

            return grid;
        }

        private inline void update_bar (Pomodoro.CanvasItem item,
                                        uint                bucket_index)
        {
            item.child.set_data<uint> ("bucket-index", bucket_index);
            item.x = (float) bucket_index;
            item.y = 0.0f;
            item.x_origin = this.bar_radius;
            item.y_origin = this.bar_height - this.bar_radius;

            item.child.queue_resize ();
        }

        private Pomodoro.CanvasItem create_bar (uint bucket_index)
        {
            var bar = new Pomodoro.Gizmo (this.measure_bar,
                                          null,
                                          this.snapshot_bar,
                                          this.contains_bar,
                                          null,
                                          null);
            bar.focusable = false;
            bar.has_tooltip = true;
            bar.add_css_class ("bar");

            bar.query_tooltip.connect (
                (x, y, keyboard_tooltip, tooltip) => {
                    if (this.tooltip_bucket_index != bucket_index) {
                        this.tooltip_bucket_index = (int) bucket_index;
                        this.tooltip_widget = this.create_tooltip_widget (bucket_index);
                    }

                    tooltip.set_custom (this.tooltip_widget);

                    return this.tooltip_widget != null;
                });

            var item = new Pomodoro.CanvasItem (bar);
            this.update_bar (item, bucket_index);

            return item;
        }

        private void measure_bar (Pomodoro.Gizmo  gizmo,
                                  Gtk.Orientation orientation,
                                  int             for_size,
                                  out int         minimum,
                                  out int         natural,
                                  out int         minimum_baseline,
                                  out int         natural_baseline)
        {
            minimum = orientation == Gtk.Orientation.HORIZONTAL ? this.bar_width : this.bar_height;
            natural = minimum;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_bar (Pomodoro.Gizmo gizmo,
                                   Gtk.Snapshot   snapshot)
                                   requires (this.data.shape[1] == this.categories.length)
        {
            var bucket_index   = gizmo.get_data<uint> ("bucket-index");
            var category_count = this.categories.length;
            var base_value     = 0.0;
            var y_scale        = (double) this.canvas.y_scale;
            var shown          = false;

            if (this._stacked)
            {
                for (var category_index = 0; category_index < category_count; category_index++)
                {
                    base_value += this.data.@get ((int) bucket_index, category_index);
                }
            }

            for (var category_index = category_count - 1; category_index >= 0; category_index--)
            {
                var category_value = this.data.@get ((int) bucket_index, category_index);  // TODO: rename to bar_value

                if (!this._stacked) {
                    base_value = category_value;
                }

                if (category_value * y_scale < MIN_BAR_HEIGHT &&
                    (category_index != 0 || shown))
                {
                    // TODO: This is not good enough if there's first category + marginal values in the following categories.
                    //       Pre-calculate displayed values beforehand.
                    base_value -= category_value;
                    continue;
                }

                var category_color  = this.categories[category_index].color;
                var category_y      = (float) (this.bar_height - this.bar_width) - (float) (base_value * y_scale);
                var category_height = (float) (category_value * y_scale) + (float) this.bar_width;

                var bounds = Graphene.Rect ();
                bounds.init (0.0f,
                             category_y,
                             this.bar_width,
                             category_height);

                var outline = Gsk.RoundedRect ();
                outline.init_from_rect (bounds, (float) this.bar_width / 2.0f);

                snapshot.push_rounded_clip (outline);
                snapshot.append_color (category_color, bounds);
                snapshot.pop ();

                base_value -= category_value;
                shown = true;
            }
        }

        private bool contains_bar (Pomodoro.Gizmo gizmo,
                                   double         x,
                                   double         y)
        {
            if (!gizmo.get_mapped ()) {
                return false;
            }

            // Check if cursor fits within bar boundaries.
            var point = Graphene.Point () {
                x = (float) x,
                y = (float) y
            };
            Graphene.Rect bounds;

            gizmo.compute_bounds (gizmo, out bounds);

            if (!bounds.contains_point (point)) {
                return false;
            }

            // Offset the cursor position to account for the bar radius and then same,
            // so we can check cursor against bar value.
            var bucket_index = gizmo.get_data<uint> ("bucket-index");

            point.y += this.bar_radius + 10.0f;
            point = this.canvas.transform.transform_point (point);

            var max_value = this._stacked
                    ? this.calculate_bucket_sum (bucket_index)
                    : this.calculate_bucket_max (bucket_index);

            return point.y <= max_value;
        }

        private inline bool is_bar (Pomodoro.CanvasItem item)
        {
            return item.child.has_css_class ("bar");
        }

        private void update_bars ()
        {
            var bucket_count = this.buckets.length;
            var bucket_index = this.skip_empty_bucket_index (0U);

            // Update `bucket-index` for existing bars. Remove extra items.
            this.canvas.@foreach (
                (item) => {
                    if (!this.is_bar (item)) {
                        return;
                    }

                    if (bucket_index < bucket_count)
                    {
                        this.update_bar (item, bucket_index);

                        bucket_index = this.skip_empty_bucket_index (bucket_index + 1);
                    }
                    else {
                        this.canvas.remove_item (item);
                    }
                });

            // Create missing bars
            while (true)
            {
                if (bucket_index < bucket_count)
                {
                    this.canvas.add_item (this.create_bar (bucket_index));

                    bucket_index = this.skip_empty_bucket_index (bucket_index + 1);
                }
                else {
                    break;
                }
            }
        }


        /*
         * Axes
         */

        public override string format_x_value (double value)
        {
            var bucket_index = (int) value;

            return bucket_index >= 0 && bucket_index < this.buckets.length
                    ? this.buckets[bucket_index].label
                    : "∅";  // for debugging
        }


        /*
         * Widget
         */

        protected override void calculate_values_range (out double x_range_from,
                                                        out double x_range_to,
                                                        out double y_range_from,
                                                        out double y_range_to)
        {
            if (this.max_value.is_nan ()) {
                this.max_value = this.calculate_max_value ();
            }

            x_range_from = 0.0;
            x_range_to   = (double) (this.buckets.length - 1);
            y_range_from = 0.0;
            y_range_to   = this.max_value;
        }

        /**
         * content size - includes bar caps / padding
         * working area - area representing values
         */
        public override void update_content (int               available_width,
                                             int               available_height,
                                             out Gdk.Rectangle working_area)
        {
            var bucket_count = this.buckets.length;  // TODO: remove buckets, use data only?

            // Estimate content size
            // Try increasing spacing to fill `available_width`.
            var max_bar_spacing = int.max (
                    (int) Math.floorf ((float) MAX_BAR_WIDTH * BAR_SPACING),
                    this.x_axis.label_width - MAX_BAR_WIDTH + MIN_BAR_SPACING);
            var min_width       = (MIN_BAR_WIDTH + MIN_BAR_SPACING) * bucket_count - MIN_BAR_SPACING + this.x_axis.label_width;
            var max_width       = (MAX_BAR_WIDTH + max_bar_spacing) * bucket_count - max_bar_spacing + this.x_axis.label_width;

            max_width = int.min ((int) Math.roundf (MAX_EXPANSION * (float) max_width), available_width);

            var nat_width       = available_width.clamp (min_width, max_width);
            var x_spacing       = nat_width / bucket_count;

            // Calculate optimal bar size and spacing
            var bar_spacing = int.max ((int) Math.floorf (BAR_SPACING * (float) x_spacing),
                                       MIN_BAR_SPACING);
            var bar_width   = int.min (x_spacing - bar_spacing, MAX_BAR_WIDTH);
            var bar_radius  = bar_width / 2;
            var bar_height  = available_height;

            if (this.bar_width != bar_width ||
                this.bar_height != bar_height ||
                this.dirty)
            {
                this.bar_width  = bar_width;
                this.bar_height = bar_height;
                this.bar_radius = bar_radius;
                this.dirty      = false;

                this.update_bars ();
            }

            working_area = Gtk.Allocation () {
                x      = x_spacing / 2,
                y      = bar_width - bar_radius,
                width  = x_spacing * (bucket_count - 1),
                height = bar_height - bar_width
            };
        }

        public override void dispose ()
        {
            this.data           = null;
            this.categories     = null;
            this.buckets        = null;
            this.tooltip_widget = null;

            base.dispose ();
        }
    }
}
