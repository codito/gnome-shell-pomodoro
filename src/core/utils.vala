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
    private inline void ensure_timestamp (ref int64 timestamp)
    {
        if (timestamp < 0) {
            timestamp = Pomodoro.Timestamp.from_now ();
        }
    }

    /**
     * Round seconds to 1s, 5s, 10s, 1m.
     *
     * Its intended for displaying rough estimation of duration.
     */
    public double round_seconds (double seconds)
    {
        if (seconds < 10.0) {
            return Math.round (seconds);
        }

        if (seconds < 30.0) {
            return 5.0 * Math.round (seconds / 5.0);
        }

        if (seconds < 60.0) {
            return 10.0 * Math.round (seconds / 10.0);
        }

        return 60.0 * Math.round (seconds / 60.0);
    }

    /**
     * Convert seconds to text.
     *
     * If hours are present, seconds are omitted.
     */
    public string format_time (uint seconds)
    {
        var hours = seconds / 3600;
        var minutes = (seconds % 3600) / 60;
        var str = "";

        seconds = seconds % 60;

        if (hours > 0)
        {
            str = ngettext ("%u hour", "%u hours", hours).printf (hours);
        }

        if (minutes > 0)
        {
            if (str != "") {
                str += " ";
            }

            str += ngettext ("%u minute", "%u minutes", minutes).printf (minutes);
        }

        if (seconds > 0 && hours == 0)
        {
            if (str != "") {
                str += " ";
            }

            str += ngettext ("%u second", "%u seconds", seconds).printf (seconds);
        }

        return str;
    }

    public inline double lerp (double value_from,
                               double value_to,
                               double t)
    {
        return value_from + (value_to - value_from) * t;
    }


    // ---------------------------------------------------------------------------


    public const double USEC_PER_SEC = 1000000.0;  // TODO: remove, use Timestamp.from_seconds() and Timestamp.to_seconds()

    private int64 reference_time = -1;  // TODO: move to timer-progress-bar.vala

    // /**
    //  * Fake Pomodoro.get_current_time (). Added for unittesting.
    //  */
    // public void freeze_time (int64 timestamp = Pomodoro.get_current_time ())
    // {
    //     Pomodoro.frozen_time = timestamp;
    // }

    // /**
    //  * Revert freeze_time() call
    //  */
    // public void unfreeze_time ()
    // {
    //     Pomodoro.frozen_time = -1;
    // }

    /**
     * Returns the number of microseconds since January 1, 1970 UTC or frozen time
     *
     * TODO deprecated, use Timestamp.from_now()
     */
    public int64 get_current_time ()
    {
        return Pomodoro.Timestamp.from_now ();
    }

    /**
     * Synchronize monotonic time with real time
     *
     * TODO move to timer-progress-bar.vala
     */
    public void sync_monotonic_time ()
    {
        Pomodoro.reference_time = GLib.get_real_time () - GLib.get_monotonic_time ();
    }

    /**
     * Convert monotonic timestamp to real time, in microseconds
     *
     * TODO move to timer-progress-bar.vala
     */
    public int64 to_real_time (int64 monotonic_time)
    {
        if (Pomodoro.reference_time == -1) {
            Pomodoro.sync_monotonic_time ();
        }

        return monotonic_time + Pomodoro.reference_time;
    }
}
