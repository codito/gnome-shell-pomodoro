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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/stats-day-page.ui")]
    private class StatsDayPage : Gtk.Box, Pomodoro.StatsPage
    {
        public Gom.Repository repository { get; construct; }

        public GLib.Date date { get; construct; }

        [GtkChild]
        private unowned Pomodoro.Histogram histogram;

        construct
        {
            this.histogram.reference_value = 3600.0;  // 1 hour (same as bucket size)
            this.histogram.y_spacing = 1800.0;  // 30 minutes
            this.histogram.set_format_value_func (
                (value) => {
                    return Pomodoro.Interval.format_short (Pomodoro.Interval.from_seconds (value));
                });

            this.histogram.add_category ("Pomodoro");
            this.histogram.add_category ("Screen Time");

            // TODO: fetch true range from db + expand to usual hours
            var hour_start = 0;
            var hour_end = 23;
            var span = 2;
            var random = new GLib.Rand ();
            var bucket_index = 0;

            for (var hour = hour_start; hour <= hour_end; hour += span)
            {
                var hour_value = GLib.Value (typeof (uint));
                hour_value.set_uint (hour);

                this.histogram.add_bucket (
                        "%d:00".printf (hour),
                        hour_value);
            }

            for (var hour = hour_start; hour <= hour_end; hour += span)
            {
                var value_1 = random.double_range (0.0, 3600.0);
                var value_2 = value_1 + random.double_range (0.0, 3600.0 - value_1);

                if (hour == 0) {
                    value_1 = 3600.0;
                    value_2 = 0.0;
                }

                if (hour == 2) {
                    value_1 = 0.0;
                    value_2 = 0.0;
                }

                if (hour == 4) {
                    value_1 = 0.0;
                    value_2 = 1800.0;
                }

                this.histogram.set_tooltip_label (
                        bucket_index,
                        "%d:00 – %d:59".printf (hour, hour + span - 1));
                this.histogram.set_values (
                        bucket_index,
                        { value_1, value_2 });

                bucket_index++;
            }
        }

        public StatsDayPage (Gom.Repository repository,
                             GLib.Date      date)
        {
            GLib.Object (
                repository: repository,
                date: date
            );
        }

        private void update_category_colors ()
        {
            var foreground_color = get_foreground_color (this.histogram);
            var background_color = get_background_color (this.histogram);

            foreground_color = blend_colors (background_color, foreground_color);

            var pomodoro_color = foreground_color;
            var screen_time_color = mix_colors (background_color, foreground_color, 0.2f);

            this.histogram.set_category_color (0U, pomodoro_color);
            this.histogram.set_category_color (1U, screen_time_color);
        }

        public override void css_changed (Gtk.CssStyleChange change)
        {
            base.css_changed (change);

            this.update_category_colors ();
        }
    }
}
