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
    private class StatsWeekPage : StatsPage
    {
        public StatsWeekPage (Gom.Repository repository,
                              GLib.DateTime  date)
        {
            GLib.Object (date: date);

            this.repository = repository;

            this.update ();
        }

        private static GLib.DateTime normalize_datetime (GLib.DateTime datetime)
        {
            var tmp = new GLib.DateTime.local (datetime.get_year (),
                                               datetime.get_month (),
                                               datetime.get_day_of_month (),
                                               0,
                                               0,
                                               0.0);
            // GLib.DateTime constructor is not happy with negative day numbers,
            // so a separate add_days() call is needed
            return tmp.add_days (1 - datetime.get_day_of_week ());
        }

        protected override string format_datetime (GLib.DateTime date)
        {
            var now = normalize_datetime (new GLib.DateTime.now_local ());
            var week = normalize_datetime (date);
            var week_end = week.add_weeks (1).add_seconds (-1.0);

            if (date.compare (now) == 0) {
                return _("This week");
            }

            if (week.get_month () == week_end.get_month ()) {
                return "%d - %d %s".printf (
                        week.get_day_of_month (),
                        week_end.get_day_of_month (),
                        week_end.format ("%B %Y"));
            }
            else {
                return "%d %s - %d %s".printf (
                        week.get_day_of_month (),
                        week.format ("%B"),
                        week_end.get_day_of_month (),
                        week_end.format ("%B %Y"));
            }
        }

        public override GLib.DateTime get_previous_date ()
        {
            return this.date.add_weeks (-1);
        }

        public override GLib.DateTime get_next_date ()
        {
            return this.date.add_weeks (1);
        }

        public override async uint64 get_reference_value ()
        {
            return yield AggregatedEntry.get_baseline_weekly_elapsed ();
        }
    }
}
