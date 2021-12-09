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
    public const double USEC_PER_SEC = 1000000.0;

    private int64 reference_time = 0;
    private int64 current_time = -1;


    private string format_time (int seconds)
    {
        var minutes = (seconds / 60) % 60;
        var hours = (seconds / 3600);
        var str = "";

        if (hours > 0) {
            str = ngettext ("%d hour", "%d hours", hours)
                            .printf (hours);
        }

        if (minutes > 0 && str != null) {
            str += " ";
        }

        if (minutes > 0) {
            str += ngettext ("%d minute", "%d minutes", minutes)
                            .printf (minutes);
        }

        return str;
    }

    /**
     * Fake GLib.get_real_time (). Added for unittesting.
     */
    public void freeze_time (int64 timestamp = Pomodoro.get_current_time ())
    {
        this.current_time = timestamp;
    }

    public void unfreeze_time ()
    {
        this.current_time = -1;
    }

    /**
     * Returns the number of microseconds since January 1, 1970 UTC or frozen time
     */
    public int64 get_current_time ()
    {
        return this.current_time == -1
                ? GLib.get_real_time ()
                : this.current_time;
    }

    public void sync_monotonic_time ()
    {
        reference_time = GLib.get_real_time () - GLib.get_monotonic_time ();
    }

    /**
     * Convert monotonic timestamp to real time, in microseconds
     */
    public int64 to_real_time (int64 monotonic_time)
    {
        if (reference_time == 0) {
            Pomodoro.sync_monotonic_time ();
        }

        return monotonic_time + reference_time;
    }
}
