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
 */

using GLib;


namespace Pomodoro
{
    public enum AnimationMode
    {
        LINEAR,
        EASE_IN,
        EASE_IN_OUT,
        EASE_OUT,
        EASE_IN_CUBIC,
        EASE_IN_OUT_CUBIC,
        EASE_OUT_CUBIC,
        BLINK
    }

    private delegate double AnimationFunc (double progress);

    public class Animation : GLib.InitiallyUnowned
    {
        public GLib.Object     target            { get; construct set; }
        public string          property_name     { get; construct set; }
        public AnimationMode   mode              { get; construct set; default = AnimationMode.LINEAR; }
        public uint            duration          { get; construct set; default = 200; }
        public uint            frames_per_second { get; construct set; default = 60; }
        public double          progress          { get; private set; default = 0.0; }

        private double         value_from;
        private double         value_to;
        private int64          timestamp  = 0;
        private uint           timeout_id = 0;
        private AnimationFunc? func       = null;

        public Animation (AnimationMode mode,
                          uint          duration,
                          uint          frames_per_second)
                      requires (frames_per_second > 0)
        {
            GLib.Object (mode:              mode,
                         duration:          duration,
                         frames_per_second: frames_per_second);

            this.notify["progress"].connect (() => {
                if (this.progress == 1.0) {
                    this.complete ();
                }
            });
        }

        public void add_property (GLib.Object target,
                                  string      property_name,
                                  GLib.Value  property_value)
        {
            this.target        = target;
            this.property_name = property_name;
            this.value_to      = property_value.get_double ();
        }

        ~Animation ()
        {
            this.stop ();
        }

        public void start ()
        {
            var begin_value = GLib.Value (typeof (double));

            this.target.get_property (this.property_name, ref begin_value);

            this.value_from = begin_value.get_double ();
            this.func       = Animation.get_func (mode);
            this.timestamp  = GLib.get_real_time () / 1000;

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            if (this.duration > 0 && this.value_from != this.value_to) {
                this.timeout_id = GLib.Timeout.add (
                                    uint.min (1000 / this.frames_per_second, this.duration),
                                    (GLib.SourceFunc) this.on_timeout);
                this.progress   = 0.0;
            }
            else {
                this.progress   = 1.0;
            }
        }

        // TODO: it's so hackish...
        public void start_with_value (double value_from)
        {
            this.value_from = value_from;
            this.func       = Animation.get_func (mode);
            this.timestamp  = GLib.get_real_time () / 1000;

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            if (this.duration > 0) {
                this.timeout_id = GLib.Timeout.add (
                                    uint.min (1000 / this.frames_per_second, this.duration),
                                    (GLib.SourceFunc) this.on_timeout);
                this.progress   = 0.0;
            }
            else {
                this.progress   = 1.0;
            }
        }

        public void stop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }
        }

        private double compute_value (double progress)
        {
            var factor = this.func (progress.clamp (0.0, 1.0));

            return this.value_from + factor * (this.value_to - this.value_from);
        }

        private bool on_timeout ()
        {
            var current_timestamp = GLib.get_real_time () / 1000;

            this.progress  = (this.duration > 0)
                ? ((double)(current_timestamp - this.timestamp) / this.duration).clamp (0.0, 1.0)
                : 1.0;

            this.target.set_property (this.property_name, this.compute_value (this.progress));

            if (this.progress == 1.0)
            {
                this.timeout_id = 0;

                return false;
            }

            return true;
        }

        private static AnimationFunc? get_func (Pomodoro.AnimationMode mode)
        {
            switch (mode)
            {
                case AnimationMode.LINEAR:
                    return calculate_linear;

                case AnimationMode.EASE_IN:
                    return calculate_ease_in;

                case AnimationMode.EASE_IN_OUT:
                    return calculate_ease_in_out;

                case AnimationMode.EASE_OUT:
                    return calculate_ease_out;

                case AnimationMode.EASE_IN_CUBIC:
                    return calculate_ease_in_cubic;

                case AnimationMode.EASE_IN_OUT_CUBIC:
                    return calculate_ease_in_out_cubic;

                case AnimationMode.EASE_OUT_CUBIC:
                    return calculate_ease_out_cubic;

                case AnimationMode.BLINK:
                    return calculate_blink;
            }

            return calculate_linear;
        }

        private static double calculate_linear (double t)
        {
            return t;
        }

        private static double calculate_ease_in (double t)
        {
            return t * t;
        }

        private static double calculate_ease_in_out (double t)
        {
            t *= 2.0;

            if (t < 1.0) {
                return 0.5 * t * t;
            }
            else {
                t -= 1.0;

                return -0.5 * (t * (t - 2.0) - 1.0);
            }
        }

        private static double calculate_ease_in_out_cubic (double t)
        {
            return ((1.0 - t) + (2.0 - t)) * (t * t);
        }

        private static double calculate_ease_out (double t)
        {
            return (2.0 - t) * t;
        }

        private static double calculate_ease_in_cubic (double t)
        {
            return t * t * t;
        }

        private static double calculate_ease_out_cubic (double t)
        {
            return ((t - 3.0) * t + 3.0) * t;
        }

        private static double calculate_blink (double t)
        {
            return t < 0.5
                    ? calculate_ease_in_out (2.0 * t)
                    : 1.0 - calculate_ease_in_out (2.0 * t - 1.0);
        }

        public signal void complete ();
    }
}
