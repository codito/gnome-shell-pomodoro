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
    public enum PresenceStatus
    {
        AVAILABLE = 0,
        INVISIBLE = 1,
        BUSY = 2,
        IDLE = 3,
        DEFAULT = -1;

        public string to_string ()
        {
            switch (this)
            {
                case AVAILABLE:
                    return "available";

                case BUSY:
                    return "busy";

                case IDLE:
                    return "idle";

                case INVISIBLE:
                    return "invisible";

                default:
                    return "";
            }
        }

        public static PresenceStatus from_string (string? presence_status)
        {
            switch (presence_status)
            {
                case "available":
                    return PresenceStatus.AVAILABLE;

                case "busy":
                    return PresenceStatus.BUSY;

                case "idle":
                    return PresenceStatus.IDLE;

                case "invisible":
                    return PresenceStatus.INVISIBLE;

                default:
                    return PresenceStatus.DEFAULT;
            }
        }

        public string get_label ()
        {
            switch (this)
            {
                case AVAILABLE:
                    return _("Available");

                case BUSY:
                    return _("Busy");

                case IDLE:
                    return _("Idle");

                case INVISIBLE:
                    return _("Invisible");

                default:
                    return "";
           }
        }
    }
}
