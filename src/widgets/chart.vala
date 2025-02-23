/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;


namespace Pomodoro
{
    public delegate string FormatValueFunc (double value);


    public class Axis : Pomodoro.CanvasItem
    {
        public const int BASE_LABEL_OFFSET = 5;

        public Gtk.Orientation orientation { get; construct; }  // TODO: use Gtk.Border to handle RTL languages

        // XXX: we put an item on a canvas that already has scale - it seems redundant
        internal double scale = 1.0;
        internal uint   tick_count = 2U;
        internal uint   stride = 1U;
        internal int    label_width;
        internal int    label_height;
        internal int    label_offset;
        internal int    width;
        internal int    height;
        internal double value_from;
        internal double value_to;
        internal double value_spacing;

        private Pango.Layout[]            layouts;
        private Pomodoro.FormatValueFunc? format_value_func;

        public Axis (Gtk.Orientation                 orientation,
                     owned Pomodoro.FormatValueFunc? format_value_func = null)
        {
            GLib.Object (
                orientation: orientation
            );

            this.format_value_func = (owned) format_value_func;
            this.layouts = {};
        }

        private static double[] calculate_ticks (double value_from,
                                                 double value_to,
                                                 double value_spacing)
        {
            // XXX: we assume value_to > value_from

            var tick_from  = (int) Math.floor (value_from / value_spacing);
            var tick_to    = (int) Math.ceil (value_to / value_spacing);
            var tick_count = tick_to > tick_from ? tick_to - tick_from + 1 : 0;
            var y_ticks    = new double[tick_count];

            for (var index = 0; index < y_ticks.length; index++) {
                y_ticks[index] = (double) (tick_from + index) * value_spacing;
            }

            return y_ticks;
        }

        public void set_range (double value_from,
                               double value_to,
                               double value_spacing)
                               requires (this.child != null)
        {
            var tick_values = calculate_ticks (value_from,
                                               value_to,
                                               value_spacing);
            var context     = this.child.create_pango_context ();
            var layout      = new Pango.Layout (context);
            layout.set_ellipsize (Pango.EllipsizeMode.NONE);

            this.label_width = 0;
            this.label_height = 0;

            // TODO: estimate stride, currently we may check too many layouts

            foreach (var tick_value in tick_values)
            {
                var text = this.format_value_func (tick_value);
                layout.set_text (text, text.length);

                var tick_label_width  = 0;
                var tick_label_height = 0;
                layout.get_pixel_size (out tick_label_width, out tick_label_height);

                this.label_width = int.max (this.label_width, tick_label_width);
                this.label_height = int.max (this.label_height, tick_label_height);
            }

            if (this.value_from != value_from ||
                this.value_to != value_to ||
                this.value_spacing != value_spacing ||
                this.tick_count != tick_count)
            {
                this.value_from    = value_from;
                this.value_to      = value_to;
                this.value_spacing = value_spacing;
                this.tick_count    = tick_values.length;

                this.layouts = null;
            }

            if (this.orientation == Gtk.Orientation.HORIZONTAL) {
                this.width  = 0;
                this.height = this.label_height + Pomodoro.Axis.BASE_LABEL_OFFSET;
            }
            else {
                this.width  = this.label_width + Pomodoro.Axis.BASE_LABEL_OFFSET;
                this.height = 0;
            }
        }

        private void update_layouts ()
        {
            var layout_count = this.tick_count >= 2U
                    ? (this.tick_count - 1U) / this.stride + 1U
                    : 0U;
            var context      = this.child.create_pango_context ();
            var tick_index   = 0U;
            var layout_index = 0U;
            var last_tick_value = this.value_from;

            this.layouts = new Pango.Layout[layout_count];

            while (layout_index < layout_count)
            {
                var tick_value = (double) tick_index * this.value_spacing + this.value_from;
                var tick_label = this.format_value_func (tick_value);

                var layout = new Pango.Layout (context);
                layout.set_width (this.label_width);
                layout.set_alignment (this.orientation == Gtk.Orientation.HORIZONTAL
                                      ? Pango.Alignment.CENTER : Pango.Alignment.RIGHT);
                layout.set_ellipsize (Pango.EllipsizeMode.NONE);
                layout.set_text (tick_label, tick_label.length);

                this.layouts[layout_index] = layout;

                layout_index++;
                tick_index += this.stride;
                last_tick_value = tick_value;
            }

            if (this.orientation == Gtk.Orientation.HORIZONTAL) {
                this.width  = (int) Math.ceil ((last_tick_value - this.value_from) * this.scale) + this.label_width;
                this.height = this.label_offset + this.label_height;
            }
            else {
                this.width  = this.label_width + this.label_offset;
                this.height = (int) Math.ceil ((last_tick_value - this.value_from) * this.scale) + this.label_height;
            }
        }

        internal void update (int    available_size,
                              int    label_offset,
                              double scale)
        {
            var spacing = available_size / this.tick_count;
            var stride = 1;

            if (this.orientation == Gtk.Orientation.HORIZONTAL)
            {
                stride = int.max (
                        (int) Math.roundf ((float) this.label_width * 2.0f / (float) spacing),
                        1);
            }
            else {
                stride = int.max (
                        (int) Math.ceilf ((float) this.label_height * 2.0f / (float) spacing),
                        1);
            }

            this.label_offset = label_offset + Pomodoro.Axis.BASE_LABEL_OFFSET;
            this.scale = scale;
            this.stride = stride;

            this.update_layouts ();

            if (this.orientation == Gtk.Orientation.HORIZONTAL)
            {
                this.x_origin = this.label_width / 2;
                this.y_origin = 0;
                this.x        = (float) this.value_from;
                this.y        = 0.0f;
            }
            else {
                this.x_origin = this.width;
                this.y_origin = this.height - this.label_height / 2;
                this.x        = 0.0f;
                this.y        = (float) this.value_from;
            }

            this.child.queue_resize ();
        }

        private void measure_child (Pomodoro.Gizmo  gizmo,
                                    Gtk.Orientation orientation,
                                    int             for_size,
                                    out int         minimum,
                                    out int         natural,
                                    out int         minimum_baseline,
                                    out int         natural_baseline)
        {
            natural = orientation == Gtk.Orientation.HORIZONTAL ? this.width : this.height;
            minimum = natural;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        private void snapshot_child (Pomodoro.Gizmo gizmo,
                                     Gtk.Snapshot   snapshot)
        {
            var color = gizmo.get_color ();
            var tick_index   = 0U;
            var layout_index = 0U;

            while (layout_index < this.layouts.length)
            {
                var tick_value = (double) tick_index * this.value_spacing + this.value_from;

                unowned var layout = this.layouts[layout_index];

                var layout_position = (float) (tick_value * this.scale);
                int layout_width;
                int layout_height;
                Graphene.Point layout_origin;

                layout.get_pixel_size (out layout_width, out layout_height);

                // Pango layout is placed on the left side of origin, at the bottom
                if (this.orientation == Gtk.Orientation.HORIZONTAL) {
                    layout_origin = Graphene.Point () {
                        x = (float) this.x_origin + layout_position,
                        y = (float) this.height - (float) layout_height
                    };
                }
                else {
                    layout_origin = Graphene.Point () {
                        x = (float) this.width - (float) this.label_offset,
                        y = (float) this.y_origin - layout_position - (float) layout_height / 2.0f
                    };
                }

                snapshot.save ();
                snapshot.translate (layout_origin);
                snapshot.append_layout (layout, color);
                snapshot.restore ();

                tick_index += this.stride;
                layout_index++;
            }
        }

        protected override Gtk.Widget? create_child ()
        {
            var child = new Pomodoro.Gizmo (this.measure_child,
                                            null,
                                            this.snapshot_child,
                                            null,
                                            null,
                                            null);
            child.focusable = false;
            child.add_css_class ("axis");

            return (Gtk.Widget?) child;
        }

        public override void dispose ()
        {
            this.layouts = null;
            this.format_value_func  = null;

            base.dispose ();
        }
    }


    /**
     * Base class for drawing a 2D charts with X and Y axes.
     */
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/chart.ui")]
    public abstract class Chart : Gtk.Widget, Gtk.Buildable
    {
        private const int MIN_WIDTH = 400;
        private const int MIN_HEIGHT = 200;

        /**
         * Interval between x-ticks in value units
         */
        public double x_spacing {
            get {
                return this._x_tick_spacing;
            }
            set {
                if (this._x_tick_spacing == value) {
                    return;
                }

                this._x_tick_spacing = value;

                this.queue_allocate ();
            }
        }

        /**
         * Interval between y-ticks in value units
         */
        public double y_spacing {
            get {
                return this._y_tick_spacing;
            }
            set {
                if (this._y_tick_spacing == value) {
                    return;
                }

                this._y_tick_spacing = value;

                this.queue_allocate ();
            }
        }

        [GtkChild]
        protected unowned Pomodoro.Canvas guides;
        [GtkChild]
        protected unowned Pomodoro.Canvas canvas;
        [GtkChild]
        protected unowned Gtk.ScrolledWindow scrolled_window;

        protected Pomodoro.Axis? x_axis;
        protected Pomodoro.Axis? y_axis;
        private double           _x_tick_spacing = 1.0;
        private double           _y_tick_spacing = 1.0;
        private FormatValueFunc? format_value_func;
        private double           drag_start_x;

        static construct
        {
            set_css_name ("chart");
        }

        construct
        {
            this.x_axis = new Pomodoro.Axis (
                    Gtk.Orientation.HORIZONTAL,
                    (value) => {
                        return this.format_x_value (value);
                    });
            this.y_axis = new Pomodoro.Axis (
                    Gtk.Orientation.VERTICAL,
                    (value) => {
                        return this.format_y_value (value);
                    });

            this.canvas.add_item (this.x_axis);
            this.guides.add_item (this.y_axis);
        }

        public void set_format_value_func (owned Pomodoro.FormatValueFunc? func)
        {
            this.format_value_func = (owned) func;

            // TODO: invalidate Axis labels / layouts

            this.queue_allocate ();
        }

        public virtual string format_x_value (double value)
        {
            return "%.2f".printf (value);
        }

        public virtual string format_y_value (double value)
        {
            return this.format_value_func != null
                    ? this.format_value_func (value)
                    : "%.2f".printf (value);
        }

        [GtkCallback]
        private void on_drag_begin (double start_x,
                                    double start_y)
        {
            this.drag_start_x = this.scrolled_window.hadjustment.value;
        }

        [GtkCallback]
        private void on_pan (Gtk.GesturePan   gesture,
                             Gtk.PanDirection direction,
                             double           offset)
        {
            // TODO: test this with RTL
            if (direction == Gtk.PanDirection.LEFT) {
                offset = -offset;
            }

            // TODO: only do this if canvas is really RTL
            this.scrolled_window.hadjustment.value = this.drag_start_x - offset;
        }

        [GtkCallback]
        private void on_y_origin_notify (GLib.Object    object,
                                         GLib.ParamSpec pspec)
        {
            this.queue_allocate ();
        }

        protected abstract void calculate_values_range (out double x_range_from,
                                                        out double x_range_to,
                                                        out double y_range_from,
                                                        out double y_range_to);

        /**
         * A function for measuring and allocating content widgets. If content size exceeds
         * available size it will be scrolled. The content may include padding, `working_area`
         * represents area representing values.
         */
        protected abstract void update_content (int               available_width,
                                                int               available_height,
                                                out Gdk.Rectangle working_area);

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
            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = MIN_WIDTH;
                natural = int.max (minimum, this.width_request);
            }
            else {
                minimum = MIN_HEIGHT;
                natural = int.max (minimum, this.height_request);
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            // TODO: handle RTL
            // var is_ltr = this.get_direction () != Gtk.TextDirection.RTL;

            double        x_value_from, x_value_to, y_value_from, y_value_to;
            int           viewport_width, viewport_height;
            Gdk.Rectangle working_area;

            // Prepare axes
            // Axes serve as main guides. Estimate tick label size and the number of ticks needed.
            // After this step we can estimate axes size.
            this.calculate_values_range (out x_value_from,
                                         out x_value_to,
                                         out y_value_from,
                                         out y_value_to);

            this.x_axis.set_range (x_value_from,
                                   x_value_to,
                                   this._x_tick_spacing);
            this.y_axis.set_range (y_value_from,
                                   y_value_to,
                                   this._y_tick_spacing);

            viewport_width  = width - this.y_axis.width;
            viewport_height = height - this.x_axis.height;

            // Update canvas content
            this.update_content (viewport_width,
                                 viewport_height,
                                 out working_area);

            var x_scale = (double) working_area.width / (x_value_to - x_value_from);
            var y_scale = (double) working_area.height / (y_value_to - y_value_from);

            this.canvas.x_scale = (float) x_scale;
            this.canvas.y_scale = (float) y_scale;

            // Update ticks and calculate scale
            this.x_axis.update (working_area.width,
                                viewport_height - working_area.y - working_area.height,
                                x_scale);
            this.y_axis.update (working_area.height,
                                0,
                                y_scale);

            // Allocate direct children
            var guides_allocation = Gtk.Allocation () {
                width  = width,
                height = height
            };
            this.guides.measure (Gtk.Orientation.HORIZONTAL,
                                 guides_allocation.height,
                                 null,
                                 out guides_allocation.width,
                                 null,
                                 null);
            this.guides.measure (Gtk.Orientation.VERTICAL,
                                 guides_allocation.width,
                                 null,
                                 out guides_allocation.height,
                                 null,
                                 null);
            this.guides.allocate_size (guides_allocation, -1);

            var scrolled_window_allocation = Gtk.Allocation () {
                width  = viewport_width,
                height = height
            };
            scrolled_window_allocation.x = width - scrolled_window_allocation.width;
            this.scrolled_window.allocate_size (scrolled_window_allocation, -1);

            // Align y-origin of y-axis and canvas, so they are at the same level
            // TODO: make preallocation in Canvas to figure out y_origin earlier; Canvas.size_allocate do not use width and height anyway
            guides_allocation.y = this.canvas.y_origin - this.guides.y_origin;
            this.guides.allocate_size (guides_allocation, -1);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.guides, snapshot);
            this.snapshot_child (this.scrolled_window, snapshot);
        }

        public override void dispose ()
        {
            this.x_axis            = null;
            this.y_axis            = null;
            this.format_value_func = null;

            base.dispose ();
        }
    }
}
