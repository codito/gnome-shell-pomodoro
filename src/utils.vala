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
     * Returns the number of seconds since January 1, 1970 UTC.
     */
    public double get_current_time ()
    {
        return (double) GLib.get_real_time () / 1000000.0;
    }
}
