/*
 * Copyright (c) 2024 gnome-pomodoro contributors
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
        public Gom.Repository repository { get; construct; }

        public GLib.Date date { get; construct; }

        public StatsMonthPage (Gom.Repository repository,
                               GLib.Date      date)
        {
            GLib.Object (
                repository: repository,
                date: date
            );
        }
   }
}
