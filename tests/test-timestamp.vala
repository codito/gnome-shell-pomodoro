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
            this.add_test ("round",
                           this.test_round);
            this.add_test ("round__undefined",
                           this.test_round__undefined);

            this.add_test ("add_interval",
                           this.test_add_interval);
            this.add_test ("subtract",
                           this.test_subtract);
            this.add_test ("subtract_interval",
                           this.test_subtract_interval);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_round ()
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

        public void test_round__undefined ()
        {
            var unit = Pomodoro.Interval.SECOND;

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.round (Pomodoro.Timestamp.UNDEFINED, unit)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
        }

        public void test_add_interval ()
        {
            var interval    = Pomodoro.Interval.MINUTE;
            var timestamp_1 = Pomodoro.Timestamp.from_now ();
            var timestamp_2 = timestamp_1 + interval;

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.add_interval (timestamp_1, 0)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.add_interval (timestamp_1, interval)),
                new GLib.Variant.int64 (timestamp_2)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.add_interval (Pomodoro.Timestamp.UNDEFINED, interval)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.add_interval (Pomodoro.Timestamp.MIN, interval)),
                new GLib.Variant.int64 (interval)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.add_interval (Pomodoro.Timestamp.MAX, interval)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MAX)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.add_interval (Pomodoro.Timestamp.MIN, -interval)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MIN)
            );
        }

        public void test_subtract ()
        {
            var interval    = Pomodoro.Interval.MINUTE;
            var timestamp_1 = Pomodoro.Timestamp.from_now ();
            var timestamp_2 = timestamp_1 + interval;

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract (timestamp_1, 0)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract (timestamp_2, timestamp_1)),
                new GLib.Variant.int64 (interval)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract (timestamp_1, timestamp_2)),
                new GLib.Variant.int64 (-interval)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract (timestamp_1, Pomodoro.Timestamp.UNDEFINED)),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract (Pomodoro.Timestamp.UNDEFINED, timestamp_1)),
                new GLib.Variant.int64 (0)
            );
        }

        public void test_subtract_interval ()
        {
            var interval    = Pomodoro.Interval.MINUTE;
            var timestamp_1 = Pomodoro.Timestamp.from_now ();
            var timestamp_2 = timestamp_1 + interval;

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract_interval (timestamp_1, 0)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract_interval (timestamp_2, interval)),
                new GLib.Variant.int64 (timestamp_1)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract_interval (Pomodoro.Timestamp.UNDEFINED, interval)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract_interval (Pomodoro.Timestamp.MIN, interval)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MIN)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Timestamp.subtract_interval (Pomodoro.Timestamp.MAX, -interval)),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MAX)
            );
        }
    }


    public class IntervalTest : Tests.TestSuite
    {
        public IntervalTest ()
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
            var interval_lower = 20 * unit;
            var interval_upper = interval_lower + unit;

            var interval_1 = interval_lower + 1;
            var interval_2 = interval_lower + (unit / 2 - 1);
            var interval_3 = interval_lower + (unit / 2);
            var interval_4 = interval_lower + (unit / 2 + 1);
            var interval_5 = interval_lower + (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_1, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_2, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_3, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_4, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_5, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
        }

        public void test_round__negative ()
        {
            var unit           = Pomodoro.Interval.SECOND;
            var interval_upper = -20 * unit;
            var interval_lower = interval_upper - unit;

            var interval_1 = interval_upper - 1;
            var interval_2 = interval_upper - (unit / 2 - 1);
            var interval_3 = interval_upper - (unit / 2);
            var interval_4 = interval_upper - (unit / 2 + 1);
            var interval_5 = interval_upper - (unit - 1);

            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_1, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_2, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_3, unit)),
                new GLib.Variant.int64 (interval_upper)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_4, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (Pomodoro.Interval.round (interval_5, unit)),
                new GLib.Variant.int64 (interval_lower)
            );
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimestampTest (),
        new Tests.IntervalTest ()
    );
}
