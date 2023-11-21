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


namespace Pomodoro
{
    public class LogScale : Gtk.Scale
    {
        private const GLib.BindingFlags BINDING_FLAGS = GLib.BindingFlags.DEFAULT |
                                                        GLib.BindingFlags.SYNC_CREATE |
                                                        GLib.BindingFlags.BIDIRECTIONAL;

        public double value { get; set; }

        public new Gtk.Adjustment adjustment {
            get {
                return this._adjustment;
            }
            set {
                if (this.value_binding != null) {
                    this.value_binding.unbind ();
                    this.value_binding = null;
                }

                this._adjustment = value;

                if (this._adjustment != null) {
                    this.value_binding = this._adjustment.bind_property ("value",
                                                                         base.adjustment,
                                                                         "value",
                                                                         BINDING_FLAGS,
                                                                         this.transform_to,
                                                                         this.transform_from);
                }
            }
        }

        private Gtk.Adjustment?       _adjustment;
        private unowned GLib.Binding? value_binding;

        construct
        {
            base.adjustment = new Gtk.Adjustment (0.0, 0.0, 2.0, 0.0, 0.0, 0.0);
        }

        public LogScale ()
        {
            GLib.Object (
                orientation: Gtk.Orientation.HORIZONTAL,
                digits: -1,
                draw_value: false
            );
        }

        /**
         * Round seconds to 30s, 1m, 5m, 10m.
         *
         * Its intended for settings only to have a rounded number.
         */
        private double round_seconds (double seconds)
        {
            if (seconds < 60.0) {
                return 30.0 * Math.round (seconds / 30.0);
            }

            if (seconds < 1800.0) {
                return 60.0 * Math.round (seconds / 60.0);
            }

            if (seconds < 3600.0) {
                return 300.0 * Math.round (seconds / 300.0);
            }

            return 600.0 * Math.round (seconds / 600.0);
        }

        private inline double func (double x)
        {
            return Math.exp (x) - 1.0;
        }

        private inline double func_inv (double y)
        {
            return Math.log (y + 1.0);
        }

        /**
         * Convert inner adjustment to destination values (seconds).
         */
        private bool transform_from (GLib.Binding   binding,
                                     GLib.Value     source_value,
                                     ref GLib.Value target_value)
        {
            var seconds_lower = this._adjustment.lower;
            var seconds_upper = this._adjustment.upper;
            var base_upper    = base.adjustment.upper;
            var base_value    = source_value.get_double ();

            var t = this.func (base_value) / this.func (base_upper);
            var seconds = t * (seconds_upper - seconds_lower) + seconds_lower;

            target_value.set_double (this.round_seconds (seconds));

            return true;
        }

        /**
         * Convert outer adjustment (seconds) to inner adjustment.
         */
        private bool transform_to (GLib.Binding   binding,
                                   GLib.Value     source_value,
                                   ref GLib.Value target_value)
        {
            var seconds_lower = this._adjustment.lower;
            var seconds_upper = this._adjustment.upper;
            var base_upper    = base.adjustment.upper;
            var seconds       = source_value.get_double ();

            var t = (seconds - seconds_lower) / (seconds_upper - seconds_lower);
            var base_value = this.func_inv (t * this.func (base_upper));

            target_value.set_double (base_value);

            return true;
        }

        public override void dispose ()
        {
            if (this.value_binding != null) {
                this.value_binding.unbind ();
            }

            base.dispose ();

            this._adjustment = null;
        }
    }
}
