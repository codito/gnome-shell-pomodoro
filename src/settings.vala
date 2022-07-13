/*
 * Copyright (c) 2014 gnome-pomodoro contributors
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
    private GLib.Settings settings = null;

    public void set_settings (GLib.Settings settings)
    {
        Pomodoro.settings = settings;
    }

    public unowned GLib.Settings get_settings ()
    {
        if (Pomodoro.settings == null) {
            Pomodoro.settings = new GLib.Settings ("org.gnomepomodoro.Pomodoro");

            // TODO: unset Pomodoro.settings at application exit
        }

        return Pomodoro.settings;
    }
}


/**
 * Convenience functions for getting values from settings
 */
/*
namespace Pomodoro.Settings
{
    public uint get_cycles_per_session ()
    {
        var settings = Pomodoro.get_settings ();

        return settings.get_uint ("pomodoros-per-session");
    }

    public int64 get_pomodoro_duration ()
    {
        var settings = Pomodoro.get_settings ();
        var seconds = settings.get_uint ("pomodoro-duration");

        return (int64) seconds * Pomodoro.Interval.SECOND;
    }

    public int64 get_short_break_duration ()
    {
        var settings = Pomodoro.get_settings ();
        var seconds = settings.get_uint ("short-break-duration");

        return (int64) seconds * Pomodoro.Interval.SECOND;
    }

    public int64 get_long_break_duration ()
    {
        var settings = Pomodoro.get_settings ();
        var seconds = settings.get_uint ("long-break-duration");

        return (int64) seconds * Pomodoro.Interval.SECOND;
    }
}
*/
