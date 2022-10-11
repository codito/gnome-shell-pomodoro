/*
 * This file is part of GNOME Pomodoro
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

namespace Tests
{
    public class TimestampTest : Tests.TestSuite
    {
        public TimestampTest ()
        {
            this.add_test ("round__positive",
                           this.test_round__positive);
            this.add_test ("round__negative",
                           this.test_round__negative);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_round__positive ()
        {
            var unit            = Pomodoro.Interval.SECOND;
            var timestamp_lower = 20 * unit;
            var timestamp_upper = timestamp_lower + unit;

            var timestamp_1 = timestamp_lower + 1;
            var timestamp_2 = timestamp_lower + (unit / 2 - 1);
            var timestamp_3 = timestamp_lower + (unit / 2);
            var timestamp_4 = timestamp_lower + (unit / 2 + 1);
            var timestamp_5 = timestamp_lower + (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_1, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_2, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_3, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_4, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_5, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
        }

        public void test_round__negative ()
        {
            var unit            = Pomodoro.Interval.SECOND;
            var timestamp_upper = -20 * unit;
            var timestamp_lower = timestamp_upper - unit;

            var timestamp_1 = timestamp_upper - 1;
            var timestamp_2 = timestamp_upper - (unit/ 2 - 1);
            var timestamp_3 = timestamp_upper - (unit / 2);
            var timestamp_4 = timestamp_upper - (unit / 2 + 1);
            var timestamp_5 = timestamp_upper - (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_1, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_2, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_3, unit)),
                new GLib.Variant.int64 (timestamp_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_4, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (timestamp_5, unit)),
                new GLib.Variant.int64 (timestamp_lower)
            );
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimestampTest ()
    );
}
