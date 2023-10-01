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
    private class StatsDayPage : StatsPage
    {
        construct
        {
            this.totals_chart.height_request = 400;
        }

        public StatsDayPage (Gom.Repository repository,
                             GLib.DateTime  date)
        {
            GLib.Object (date: date);

            this.repository = repository;

            this.update ();
        }

        protected override string format_datetime (GLib.DateTime date)
        {
            // TODO: is there a better way to figure out wether date is today or yesterday?

            var now = new GLib.DateTime.now_local ();
            var today = new GLib.DateTime.local (now.get_year (),
                                                 now.get_month (),
                                                 now.get_day_of_month (),
                                                 0,
                                                 0,
                                                 0.0);
            var month = new GLib.DateTime.local (now.get_year (),
                                                 now.get_month (),
                                                 1,
                                                 0,
                                                 0,
                                                 0.0);

            if (date.compare (today) == 0) {
                return _("Today");
            }

            if (date.compare (today.add_days (-1)) == 0) {
                return _("Yesterday");
            }

            if (date.compare (month.add_months (-11)) >= 0) {
                return date.format ("%A, %e %B");
            }

            return date.format ("%e %B %Y");
        }

        public override GLib.DateTime get_previous_date ()
        {
            return this.date.add_days (-1);
        }

        public override GLib.DateTime get_next_date ()
        {
            return this.date.add_days (1);
        }

        public override async uint64 get_reference_value ()
        {
            return yield AggregatedEntry.get_baseline_daily_elapsed ();
        }
    }
}
