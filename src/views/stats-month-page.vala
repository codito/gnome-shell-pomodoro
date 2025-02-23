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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/stats-month-page.ui")]
    private class StatsMonthPage : Gtk.Box, Pomodoro.StatsPage
    {
        private const double REFERENCE_VALUE = 28800.0;  // 8 hours per day

        public Gom.Repository repository { get; construct; }

        public GLib.Date date { get; construct; }

        [GtkChild]
        private unowned Pomodoro.BubbleChart bubble_chart;


        construct
        {
            var start_date = this.date.copy ();
            start_date.subtract_days (
                    Pomodoro.DateUtils.get_weekday_number (start_date.get_weekday ()) - 1U);

            var end_date = this.date.copy ();
            end_date.add_days (
                    GLib.Date.get_days_in_month (this.date.get_month (), this.date.get_year ()) - 1U);
            end_date.add_days (
                    7U - Pomodoro.DateUtils.get_weekday_number (end_date.get_weekday ()));

            // Initialize bubble chart
            var date = start_date.copy ();
            var rows = 0;
            var columns = 7;
            var random = new GLib.Rand ();

            this.bubble_chart.reference_value = REFERENCE_VALUE;
            this.bubble_chart.set_format_value_func (
                (value) => {
                    return Pomodoro.Interval.format_short (Pomodoro.Interval.from_seconds (value));
                });
            this.bubble_chart.add_category ("Pomodoro");
            this.bubble_chart.add_category ("Screen Time");

            for (var column = 0; column < columns; column++)
            {
                this.bubble_chart.add_column (Pomodoro.DateUtils.format_date (date, "%a"));

                date.add_days (1U);
            }

            date = start_date.copy ();

            while (date.compare (end_date) < 0)
            {
                var index = this.bubble_chart.add_row (date.get_day ().to_string ());

                if (date.get_month () != this.date.get_month ()) {
                    this.bubble_chart.get_row_label (index).add_css_class ("dim-label");
                }

                date.add_days (7U);
                rows++;
            }

            date = start_date.copy ();

            for (var row = 0; row < rows; row++)
            {
                for (var column = 0; column < columns; column++)
                {
                    var value_1 = random.double_range (0.0, 3600.0 * 8);
                    var value_2 = value_1 + random.double_range (0.0, 3600.0 * 8 - value_1);

                    this.bubble_chart.set_values (row, column, { value_1, value_2 });
                    this.bubble_chart.set_tooltip_label (
                            row,
                            column,
                            capitalize_words (Pomodoro.DateUtils.format_date (date, "%e %B")));

                    date.add_days (1U);
                }
            }

            this.update_category_colors ();
        }

        public StatsMonthPage (Gom.Repository repository,
                               GLib.Date      date)
        {
            GLib.Object (
                repository: repository,
                date: date
            );
        }

        private void update_category_colors ()
        {
            var foreground_color = get_foreground_color (this.bubble_chart);
            var background_color = get_background_color (this.bubble_chart);

            foreground_color = blend_colors (background_color, foreground_color);

            var pomodoro_color = foreground_color;
            var screen_time_color = mix_colors (background_color, foreground_color, 0.2f);

            this.bubble_chart.set_category_color (0U, pomodoro_color);
            this.bubble_chart.set_category_color (1U, screen_time_color);
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            base.css_changed (change);

            this.update_category_colors ();
        }
   }
}
