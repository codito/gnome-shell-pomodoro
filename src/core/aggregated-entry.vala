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
    /**
     * Aggregate daily entries so that it's easier to display / analyse data.
     */
    public class AggregatedEntry : Gom.Resource
    {
        public const string DATE_FORMAT = "%Y-%m-%d";

        public int64 id { get; set; }
        public string date_string { get; set; }
        public string state_name { get; set; }
        public int64 state_duration { get; set; }
        public int64 elapsed { get; set; }

        static construct
        {
            set_table ("aggregated-entries");
            set_primary_key ("id");
            set_notnull ("state-name");
            set_notnull ("date-string");
        }

        private static async int64 get_max_elapsed_sum (string group_by_sql)
        {
            var adapter = Pomodoro.Database.get_repository ().get_adapter ();
            var elapsed = (int64) 0;

            adapter.queue_read (() => {
                Gom.Cursor? cursor = null;

                var command = (Gom.Command) GLib.Object.@new (typeof (Gom.Command),
                                                              adapter: adapter);
                command.set_sql ("""
SELECT """ + group_by_sql + """ AS "group", SUM("elapsed") AS "elapsed-sum"
    FROM "aggregated-entries"
    GROUP BY "group"
    ORDER BY "elapsed-sum" DESC
    LIMIT 1;
""");

                try {
                    command.execute (out cursor);

                    if (cursor != null && cursor.next ()) {
                        elapsed = cursor.get_column_int64 (1);
                    }
                    else {
                        GLib.assert_not_reached ();
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                GLib.Idle.add (get_max_elapsed_sum.callback);
            });

            yield;

            return elapsed;
        }

        public static async int64 get_baseline_daily_elapsed ()
        {
            return yield get_max_elapsed_sum ("\"date-string\"");
        }

        public static async int64 get_baseline_weekly_elapsed ()
        {
            return yield get_max_elapsed_sum ("strftime('%Y-%W', \"date-string\")");
        }

        public static async int64 get_baseline_monthly_elapsed ()
        {
            return yield get_max_elapsed_sum ("strftime('%Y-%m', \"date-string\")");
        }
    }
}
