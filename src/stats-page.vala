/*
 * Copyright (c) 2017 gnome-pomodoro contributors
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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/stats-page.ui")]
    private abstract class StatsPage : Gtk.Box, Gtk.Buildable
    {
        private const double GUIDES_OFFSET = 5.0;
        private const double GUIDES_WIDTH = 40.0;
        private const double CHART_PADDING = 20.0;
        private const double LABEL_HEIGHT = 20.0;
        private const double LABEL_OFFSET = 10.0;
        private const double BAR_MAX_WIDTH = 130.0;
        private const double BAR_RELATIVE_WIDTH = 0.85;
        private const double BAR_BORDER_RADIUS = 2.5;

        private delegate void DrawChartFunc (Cairo.Context context,
                                             double[]      values,
                                             double        x,
                                             double        y,
                                             double        width,
                                             double        height);

        struct Data
        {
            public int64 pomodoro_elapsed;
            public int64 break_elapsed;
        }

        public GLib.DateTime date {
            get {
                return this._date;
            }
            set {
                this._date = value;

                this.title = this.format_datetime (this._date);
            }
        }

        public GLib.DateTime date_end { get; set; }

        public string title { get; set; }

        [GtkChild]
        public unowned Gtk.Spinner spinner;
        [GtkChild]
        public unowned Gtk.DrawingArea timeline_chart;
        [GtkChild]
        public unowned Gtk.DrawingArea totals_chart;

        protected GLib.DateTime _date;
        protected Gom.Repository repository;
        protected uint64 reference_value;
        protected uint64 daily_reference_value;
        private GLib.HashTable<string, Data?> days;

        construct
        {
            this.days = new GLib.HashTable<string, Data?> (str_hash, str_equal);
        }

        private static string format_value (int64 seconds)
        {
            if (seconds < 3600) {
                return _("%d m").printf ((int) seconds / 60);
            }

            var part_hours = Math.round (seconds / 360.0);

            if ((int) part_hours % 10 == 0) {
                return _("%.0f h").printf (part_hours / 10.0);
            }

            return _("%.1f h").printf (part_hours / 10.0);
        }

        private static string format_day_of_month (GLib.DateTime date)
        {
            return date.get_day_of_month ().to_string ();
        }

        private static string format_day_of_week (GLib.DateTime date)
        {
            return date.format ("%A").get_char (0).toupper ().to_string ();  // first letter of localized day-of-week name
        }

        /**
         * Helper method to draw text centered inside a specified box
         */
        private static void draw_label (Cairo.Context context,
                                        string label,
                                        double x,
                                        double y,
                                        double width,
                                        double height)
        {
            Cairo.TextExtents extents;

            context.text_extents (label, out extents);
            context.move_to (x + width * 0.5 - (extents.width * 0.5 + extents.x_bearing),
                             y + height * 0.5 - (extents.height * 0.5 + extents.y_bearing));
            context.show_text (label);
        }

        /**
         * Helper method to draw grid lines with labels, all relative to reference_value.
         */
        private static void draw_guide_lines (Cairo.Context context,
                                              double        reference_value,
                                              double        x,
                                              double        y,
                                              double        width,
                                              double        height,
                                              Gdk.RGBA      color)
        {
            Cairo.TextExtents extents;

            if (reference_value <= 0.0) {
                return;
            }

            var lines      = int.max (1, (int) Math.floor (height / 135.0)),
                line_value = 0.0,
                line_label = format_value ((int64) line_value),
                line_x     = x,
                line_y     = Math.floor (y + height);

            var unit = Math.exp2 (Math.floor (Math.log2 (reference_value / (double) (lines + 1) / 3600.0)))
                * 3600.0;

            /* baseline */
            context.set_line_width (1.0);
            context.set_source_rgba (color.red,
                                     color.green,
                                     color.blue,
                                     color.alpha * 0.30);
            context.move_to (line_x, line_y + 0.5);
            context.rel_line_to (width, 0.0);
            context.stroke ();

            /* other lines, with labels */
            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);

            for (var index=0; index < lines; index++)
            {
                line_value += unit;
                line_label  = format_value ((int64) line_value);
                line_y      = Math.floor (y + height - height * line_value / reference_value);

                context.move_to (line_x, line_y + 0.5);
                context.rel_line_to (width, 0.0);
                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * 0.10);
                context.stroke ();

                context.text_extents (line_label, out extents);
                context.move_to (line_x - extents.width - extents.x_bearing - GUIDES_OFFSET,
                                 line_y - extents.height * 0.5 - extents.y_bearing - 1.0);
                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * 0.3);
                context.show_text (line_label);
            }
        }

        /**
         * Helper method to draw a single bar. It only draws paths without filling.
         */
        private static void draw_bar (Cairo.Context context,
                                      double        value,
                                      double        x,
                                      double        y,
                                      double        width,
                                      double        height)
        {
            var value_y = Math.round (y + height - value * height);
            var value_height = y + height - value_y;

            context.new_sub_path ();

            if (value_height >= BAR_BORDER_RADIUS) {
                context.move_to (x, y + height);
                context.arc (x + BAR_BORDER_RADIUS,
                             value_y + BAR_BORDER_RADIUS,
                             BAR_BORDER_RADIUS,
                             Math.PI,
                             1.5 * Math.PI);
                context.arc (x + width - BAR_BORDER_RADIUS,
                             value_y + BAR_BORDER_RADIUS,
                             BAR_BORDER_RADIUS,
                             -0.5 * Math.PI,
                             0.0);
                context.line_to (x + width, y + height);
            }
            else if (value_height != 0.0) {
                var matrix = context.get_matrix ();

                context.translate (0.0, value_y + value_height);
                context.scale (1.0, value * height / BAR_BORDER_RADIUS);
                context.arc (x + BAR_BORDER_RADIUS,
                             0.0,
                             BAR_BORDER_RADIUS,
                             Math.PI,
                             1.5 * Math.PI);
                context.arc (x + width - BAR_BORDER_RADIUS,
                             0.0,
                             BAR_BORDER_RADIUS,
                             -0.5 * Math.PI,
                             0.0);
                context.set_matrix (matrix);
            }

            context.close_path ();
        }

        /**
         * Method for drawing values as bar chart.
         */
        private static void draw_bar_chart (Cairo.Context context,
                                            double[]      values,
                                            double        x,
                                            double        y,
                                            double        width,
                                            double        height)
        {
            if (values.length > 1)
            {
                var segment_width = width / (double) values.length,
                    bar_x         = 0.0,
                    bar_y         = y,
                    bar_width     = 0.0,
                    bar_height    = height;

                bar_width = double.min (
                    Math.floor (segment_width * BAR_RELATIVE_WIDTH),
                    BAR_MAX_WIDTH);

                bar_x = x + Math.floor ((segment_width - bar_width) / 2.0);

                for (var index = 0; index < values.length; index++)
                {
                    draw_bar (context,
                              values[index],
                              bar_x + segment_width * (double) index,
                              bar_y,
                              bar_width,
                              bar_height);
                }
            }
        }

        /**
         * Method for drawing values as smooth line chart.
         */
        private static void draw_line_chart (Cairo.Context context,
                                             double[]      values,
                                             double        x,
                                             double        y,
                                             double        width,
                                             double        height)
        {
            if (values.length > 1)
            {
                var segment_width = width / (double) (values.length - 1);

                var x0     = x - segment_width,
                    y0     = y + height,
                    x1     = 0.0,
                    y1     = 0.0,
                    x2     = 0.0,
                    y2     = 0.0,
                    x3     = 0.0,
                    y3     = 0.0,
                    x6     = 0.0,
                    y6     = 0.0,
                    slope0 = 0.0,
                    slope3 = 0.0;

                context.new_path ();
                context.move_to (x0, y0);

                for (var index=-1; index < values.length; index++)
                {
                    x3 = x0 + segment_width;
                    y3 = y + height * (1.0 - (index + 1 < values.length ? values[index + 1] : 0.0));

                    x6 = x3 + segment_width;
                    y6 = y + height * (1.0 - (index + 2 < values.length ? values[index + 2] : 0.0));

                    slope3 = (y6 - y0) / (x6 - x0);

                    x1 = x0 + (x3 - x0) * 0.5;
                    y1 = y0 + slope0 * (x1 - x0);
                    x2 = x3 - (x3 - x0) * 0.5;
                    y2 = y3 + slope3 * (x2 - x3);

                    context.curve_to (x1, y1,
                                      x2, y2,
                                      x3, y3);

                    x0     = x3;
                    y0     = y3;
                    slope0 = slope3;
                }
            }
        }

        /*
        [GtkCallback]
        private bool on_timeline_chart_draw (Gtk.Widget    widget,
                                             Cairo.Context context)
        {
            var style_context   = widget.get_style_context ();
            var width           = (double) widget.get_allocated_width ();
            var height          = (double) widget.get_allocated_height ();
            var chart_x         = GUIDES_WIDTH + CHART_PADDING;
            var chart_y         = 0.0;
            var chart_width     = width - 2.0 * (GUIDES_WIDTH + CHART_PADDING);
            var chart_height    = height - LABEL_OFFSET - LABEL_HEIGHT;

            var days_count      = (int) (this.date_end.difference (this.date) / GLib.TimeSpan.DAY);
            var pomodoro_values = new double[days_count];
            var total_values    = new double[days_count];
            var reference_value = double.max (this.daily_reference_value, 3600.0);
            var draw_chart_func = (DrawChartFunc) draw_bar_chart;

            var label_x      = chart_x;
            var label_y      = chart_y + chart_height;
            var label_width  = chart_width / (double) days_count;
            var label_height = LABEL_HEIGHT;

            if (days_count > 7) {
                draw_chart_func = (DrawChartFunc) draw_line_chart;
            }

            Cairo.TextExtents label_extents;
            Gdk.RGBA theme_fg_color = style_context.get_color ();
            Gdk.RGBA theme_bg_color;
            Gdk.RGBA theme_selected_bg_color;

            style_context.lookup_color ("theme_selected_bg_color", out theme_selected_bg_color);
            style_context.lookup_color ("theme_bg_color", out theme_bg_color);

            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            context.set_font_size (13.0);
            context.set_source_rgba
                    (theme_fg_color.red,
                     theme_fg_color.green,
                     theme_fg_color.blue,
                     theme_fg_color.alpha);

            // collect data and draw labels
            for (var index=0; index < days_count; index++)
            {
                var date = this.date.add_days (index);
                var day  = this.days.lookup (date.format ("%Y-%m-%d"));

                if (day != null) {
                    pomodoro_values[index] = day.pomodoro_elapsed / reference_value;
                    total_values[index] = (day.pomodoro_elapsed + day.break_elapsed) / reference_value;
                }
                else {
                    pomodoro_values[index] = 0.0;
                    total_values[index] = 0.0;
                }

                if (days_count > 7 && date.get_day_of_week () != 1) {
                    continue;
                }

                var label_text = days_count <= 7
                    ? format_day_of_week (date)
                    : format_day_of_month (date);

                label_x = chart_x + label_width * (double) index;

                context.text_extents (label_text, out label_extents);
                context.move_to (label_x + (label_width - label_extents.width) * 0.5 - label_extents.x_bearing,
                                 label_y + (label_height - label_extents.height) * 0.5 - label_extents.y_bearing);
                context.show_text (label_text);
            }

            // grid
            draw_guide_lines (context,
                              reference_value,
                              chart_x - CHART_PADDING,
                              chart_y,
                              chart_width + 2.0 * CHART_PADDING,
                              chart_height,
                              theme_fg_color);

            context.rectangle (0.0, chart_y, width, chart_height);
            context.clip ();

            // totals chart
            context.set_source_rgba
                    (theme_selected_bg_color.red   * 0.8 + theme_bg_color.red   * 0.2,
                     theme_selected_bg_color.green * 0.8 + theme_bg_color.green * 0.2,
                     theme_selected_bg_color.blue  * 0.8 + theme_bg_color.blue  * 0.2,
                     theme_selected_bg_color.alpha * 0.6);
            draw_chart_func (context,
                             total_values,
                             chart_x,
                             chart_y,
                             chart_width,
                             chart_height);
            context.fill ();

            // pomodoro chart
            context.set_source_rgba
                    (theme_selected_bg_color.red,
                     theme_selected_bg_color.green,
                     theme_selected_bg_color.blue,
                     theme_selected_bg_color.alpha);
            draw_chart_func (context,
                             pomodoro_values,
                             chart_x,
                             chart_y,
                             chart_width,
                             chart_height);
            context.fill ();

            return false;
        }
        */

        /*
        [GtkCallback]
        private bool on_totals_chart_draw (Gtk.Widget    widget,
                                           Cairo.Context context)
        {
            var style_context   = widget.get_style_context ();
            var width           = (double) widget.get_allocated_width ();
            var height          = (double) widget.get_allocated_height ();
            var chart_x         = GUIDES_WIDTH + CHART_PADDING;
            var chart_y         = 0.0;
            var chart_width     = width - 2.0 * (GUIDES_WIDTH + CHART_PADDING);
            var chart_height    = height - LABEL_OFFSET - 2.0 * LABEL_HEIGHT;

            var reference_value = double.max (this.reference_value, 3600.0);
            var bar_x           = 0.0;
            var bar_y           = chart_y;
            var bar_width       = BAR_MAX_WIDTH;
            var bar_height      = chart_height;
            var bar_spacing     = 20.0;

            var label_x      = bar_x;
            var label_y      = bar_y + bar_height;
            var label_width  = bar_width;
            var label_height = LABEL_HEIGHT;

            Gdk.RGBA theme_selected_bg_color;
            Gdk.RGBA theme_border_color;
            Gdk.RGBA theme_fg_color = style_context.get_color ();

            style_context.lookup_color ("theme_selected_bg_color", out theme_selected_bg_color);
            style_context.lookup_color ("borders", out theme_border_color);

            // collect data
            var totals = Data ();

            this.days.for_each ((date_string, data) => {
                totals.pomodoro_elapsed += data.pomodoro_elapsed;
                totals.break_elapsed += data.break_elapsed;
            });

            // grid
            draw_guide_lines (context,
                              reference_value,
                              chart_x - CHART_PADDING,
                              chart_y,
                              chart_width + 2.0 * CHART_PADDING,
                              chart_height,
                              theme_fg_color);

            // pomodoro bar
            bar_x = Math.floor (chart_x + chart_width / 2.0 - bar_spacing / 2.0 - bar_width);

            context.set_source_rgba
                    (theme_selected_bg_color.red,
                     theme_selected_bg_color.green,
                     theme_selected_bg_color.blue,
                     theme_selected_bg_color.alpha);
            draw_bar (context,
                      totals.pomodoro_elapsed / reference_value,
                      bar_x,
                      bar_y,
                      bar_width,
                      bar_height);
            context.fill ();

            // pomodoro bar: label
            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            context.set_font_size (14.0);
            context.set_source_rgba
                    (theme_fg_color.red,
                     theme_fg_color.green,
                     theme_fg_color.blue,
                     theme_fg_color.alpha);

            label_x = bar_x;
            label_y = bar_y + bar_height + LABEL_OFFSET;

            draw_label (context,
                        _("Pomodoro"),
                        label_x,
                        label_y,
                        label_width,
                        label_height);

            // pomodoro bar: total value
            label_y += label_height;

            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            draw_label (context,
                        format_value (totals.pomodoro_elapsed),
                        label_x,
                        label_y,
                        label_width,
                        label_height);

            // break bar
            bar_x = Math.floor (chart_x + chart_width / 2.0 + bar_spacing / 2.0);

            context.set_source_rgba
                    (theme_selected_bg_color.red,
                     theme_selected_bg_color.green,
                     theme_selected_bg_color.blue,
                     theme_selected_bg_color.alpha);
            draw_bar (context,
                      totals.break_elapsed / reference_value,
                      bar_x,
                      bar_y,
                      bar_width,
                      bar_height);
            context.fill ();

            // break bar: label
            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.BOLD);
            context.set_font_size (14.0);
            context.set_source_rgba
                    (theme_fg_color.red,
                     theme_fg_color.green,
                     theme_fg_color.blue,
                     theme_fg_color.alpha);

            label_x = bar_x;
            label_y = bar_y + bar_height + LABEL_OFFSET;

            draw_label (context,
                        _("Break"),
                        label_x,
                        label_y,
                        label_width,
                        label_height);

            // break bar: total value
            label_y += label_height;

            context.select_font_face ("Sans", Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            draw_label (context,
                        format_value (totals.break_elapsed),
                        label_x,
                        label_y,
                        label_width,
                        label_height);

            return false;
        }
        */

        public void update ()
        {
            this.date_end = this.get_next_date ();

            this.timeline_chart.visible = false;
            this.totals_chart.visible = false;
            this.spinner.spinning = true;

            this.fetch.begin ((obj, res) => {
                this.fetch.end (res);

                this.timeline_chart.visible = this.date_end.compare (this.date.add_weeks (1)) >= 0;
                this.totals_chart.visible = true;
                this.spinner.spinning = false;

                if (this.timeline_chart.get_mapped ()) {
                    this.timeline_chart.queue_draw ();
                }

                if (this.totals_chart.get_mapped ()) {
                    this.totals_chart.queue_draw ();
                }
            });
        }

        protected async void fetch ()
        {
            this.days.remove_all ();

            var date_start = this.date.format (Pomodoro.AggregatedEntry.DATE_FORMAT);
            var date_end = this.date_end.format (Pomodoro.AggregatedEntry.DATE_FORMAT);

            var filter = new Gom.Filter.and (
                new Gom.Filter.gte (typeof (Pomodoro.AggregatedEntry), "date-string", date_start),
                new Gom.Filter.lt (typeof (Pomodoro.AggregatedEntry), "date-string", date_end)
            );

            var reference_value = yield this.get_reference_value ();

            var daily_reference_value = yield AggregatedEntry.get_baseline_daily_elapsed ();

            this.repository.find_async.begin (typeof (Pomodoro.AggregatedEntry), filter, (obj, res) => {
                try {
                    var group = this.repository.find_async.end (res);

                    if (group.count > 0) {
                        group.fetch_async.begin (0, group.count, (obj, res) => {
                            try {
                                group.fetch_async.end (res);

                                for (var index = 0; index < group.count; index++) {
                                    var aggregated_entry = group.get_index (index) as Pomodoro.AggregatedEntry;

                                    Data? day = this.days.lookup (aggregated_entry.date_string);

                                    if (day == null) {
                                        day = Data ();
                                    }

                                    switch (aggregated_entry.state_name) {
                                        case "pomodoro":
                                            day.pomodoro_elapsed += aggregated_entry.elapsed;
                                            break;

                                        case "break":
                                        case "short-break":
                                        case "long-break":
                                            day.break_elapsed += aggregated_entry.elapsed;
                                            break;

                                        default:
                                            break;
                                    }

                                    this.days.insert (aggregated_entry.date_string, day);
                                }
                            }
                            catch (GLib.Error error) {
                                GLib.critical ("%s", error.message);
                            }
                        });
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                this.reference_value = reference_value;
                this.daily_reference_value = daily_reference_value;

                fetch.callback ();
            });

            yield;
        }

        protected virtual string format_datetime (GLib.DateTime date)
        {
            assert_not_reached ();
        }

        public virtual GLib.DateTime get_previous_date ()
        {
            assert_not_reached ();
        }

        public virtual GLib.DateTime get_next_date ()
        {
            assert_not_reached ();
        }

        public virtual async uint64 get_reference_value ()
        {
            return 0;
        }
    }
}
