/*
 * Copyright (c) 2017 gnome-pomodoro contributors
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
    internal class Entry : Gom.Resource
    {
        public int64 id { get; set; }
        /* Not very efficient to store state names, but seems more future proof
         * in case new states were added. Also, we don't really need an "id" column,
         * but Gom doesn't support having primary key consisting of few columns yet.
         */
        public string state_name { get; set; }
        public int64 state_duration { get; set; }
        public int64 elapsed { get; set; }

        /* Store current local date and time as string. We want to keep the original date and time.
         * For this we could store timezone name/offset, but date formatted strings can be used straight
         * as a column index in sqlite, and it's crucial to lookup entries by day.
         */
        public string datetime_string { get; set; }
        public string datetime_local_string { get; set; }

        static construct
        {
            set_table ("entries");
            set_primary_key ("id");
            set_notnull ("state-name");
            set_notnull ("datetime-string");
            set_notnull ("datetime-local-string");
        }

        // public Entry.from_state (Pomodoro.TimerState state)
        // {
        //     var datetime = new GLib.DateTime.from_unix_utc (
        //         (int64) Math.floor (state.timestamp));

        //     this.state_name     = state.name;
        //     this.state_duration = (int64) Math.floor (state.duration);
        //     this.elapsed        = (int64) Math.floor (state.elapsed);
        //     this.set_datetime (datetime);
        // }

        public void set_datetime (GLib.DateTime value)
        {
            this.datetime_string = value.to_string ();
            this.datetime_local_string = value.to_local ().format ("%Y-%m-%dT%H:%M:%S");
        }

        public GLib.DateTime? get_datetime_local ()
        {
            return new GLib.DateTime.from_iso8601 (this.datetime_local_string, new TimeZone.local ());
        }
    }
}
