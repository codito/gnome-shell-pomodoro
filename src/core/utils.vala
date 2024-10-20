/*
 * Copyright (c) 2013, 2024 gnome-pomodoro contributors
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
    private static int _is_flatpak = -1;


    public inline void ensure_timestamp (ref int64 timestamp)
    {
        if (Pomodoro.Timestamp.is_undefined (timestamp)) {
            timestamp = Pomodoro.Timestamp.from_now ();
        }
    }


    public inline string ensure_string (string? str)
    {
        return str != null ? str : "";
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

    public bool is_flatpak ()
    {
        if (_is_flatpak < 0) {
            var value = GLib.Environment.get_variable ("container") == "flatpak" &&
                        GLib.Environment.get_variable ("G_TEST_ROOT_PROCESS") == null;
            _is_flatpak = value ? 1 : 0;
        }

        return _is_flatpak > 0;
    }

    internal bool is_test ()
    {
        return GLib.Environment.get_variable ("G_TEST_ROOT_PROCESS") != null;
    }

    public string to_camel_case (string name)
    {
        var     result = new GLib.StringBuilder ();
        var     was_hyphen = false;
        unichar chr;
        int     chr_span_end = 0;

        while (name.get_next_char (ref chr_span_end, out chr))
        {
            if (chr == '-') {
                was_hyphen = true;
                continue;
            }

            if (was_hyphen) {
                was_hyphen = false;
                result.append_unichar (chr.toupper ());
            }
            else {
                result.append_unichar (chr);
            }
        }

        return result.str;
    }


    public string from_camel_case (string name)
    {
        var     result = new GLib.StringBuilder ();
        var     was_lowercase = false;
        unichar chr;
        int     chr_span_end = 0;

        while (name.get_next_char (ref chr_span_end, out chr))
        {
            if (chr.isupper () && was_lowercase) {
                was_lowercase = false;
                result.append_c ('-');
                result.append_unichar (chr.tolower ());
            }
            else {
                was_lowercase = chr.islower ();
                result.append_unichar (was_lowercase ? chr : chr.tolower ());
            }
        }

        return result.str;
    }
}
