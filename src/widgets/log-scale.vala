/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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


namespace Pomodoro.Widgets
{
    public class LogScale : Gtk.Scale
    {
        /* TODO: This widget is quite bad. We need custom GtkRange to
         *       do it right.
         */

        public double exponent { get; set; default = 1.0; }

        public Gtk.Adjustment base_adjustment { get; private set; }

        public LogScale (Gtk.Adjustment adjustment,
                         double         exponent)
        {
            GLib.Object (
                orientation: Gtk.Orientation.HORIZONTAL,
                digits: -1,
                draw_value: false,
                margin_top: 4,
                halign: Gtk.Align.FILL
            );

            this.exponent = exponent;

            this.do_set_adjustment (adjustment);
        }

        private void do_set_adjustment (Gtk.Adjustment base_adjustment)
        {
            var binding_flags =
                    GLib.BindingFlags.DEFAULT |
                    GLib.BindingFlags.BIDIRECTIONAL |
                    GLib.BindingFlags.SYNC_CREATE;

            this.adjustment = new Gtk.Adjustment (0.0,
                                                  0.0,
                                                  1.0,
                                                  0.0001,
                                                  0.001,
                                                  0.0);

            this.base_adjustment = base_adjustment;
            this.base_adjustment.bind_property ("value",
                                                this.adjustment,
                                                "value",
                                                binding_flags,
                                                this.transform_to,
                                                this.transform_from);
        }

        private bool transform_from (GLib.Binding   binding,
                                     GLib.Value     source_value,
                                     ref GLib.Value target_value)
        {
            var lower = this.base_adjustment.lower;
            var upper = this.base_adjustment.upper;
            var step_increment = this.base_adjustment.step_increment;

            var value = Math.pow (source_value.get_double (), this.exponent) * (upper - lower) + lower;

            target_value.set_double (step_increment * Math.floor (value / step_increment));

            return true;
        }

        private bool transform_to (GLib.Binding   binding,
                                   GLib.Value     source_value,
                                   ref GLib.Value target_value)
        {
            var lower = this.base_adjustment.lower;
            var upper = this.base_adjustment.upper;

            target_value.set_double (Math.pow (
                    (source_value.get_double () - lower) / (upper - lower),
                    1.0 / this.exponent));

            return true;
        }

        // TODO: port to gtk4?
        // public override bool scroll_event (Gdk.EventScroll event)
        // {
        //     return false;
        // }
    }
}
