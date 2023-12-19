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
    public class CapabilityGroupTest : Tests.TestSuite
    {
        public CapabilityGroupTest ()
        {
            this.add_test ("add", this.test_add);
            this.add_test ("remove", this.test_remove);
            this.add_test ("dispose", this.test_dispose);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        /**
         * Unit test for Pomodoro.CapabilityGroup.add() method.
         */
        public void test_add ()
        {
            var signal_emit_count = 0;

            var group      = new Pomodoro.CapabilityGroup ("test");
            var capability = new Pomodoro.SimpleCapability ("anti-gravity", null, null);

            group.added.connect (() => {
                signal_emit_count++;
            });

            assert_true (group.add (capability));
            assert_true (group.contains ("anti-gravity"));
            assert_cmpuint (signal_emit_count, GLib.CompareOperator.EQ, 1);

            assert_false (group.add (capability));
        }

        /**
         * Unit test for Pomodoro.CapabilityGroup.remove() method.
         */
        public void test_remove ()
        {
            var group      = new Pomodoro.CapabilityGroup ("test");
            var capability = new Pomodoro.SimpleCapability ("anti-gravity", null, null);

            var signal_emit_count = 0;

            group.removed.connect (() => {
                signal_emit_count++;
            });

            group.add (capability);

            assert_true (group.remove (capability));
            assert_false (group.contains ("anti-gravity"));
            assert_cmpuint (signal_emit_count, GLib.CompareOperator.EQ, 1);

            assert_false (group.remove (capability));
        }

        /**
         * Unit test for Pomodoro.CapabilityGroup.dispose() method.
         */
        public void test_dispose ()
        {
            var group      = new Pomodoro.CapabilityGroup ("test");
            var capability = new Pomodoro.SimpleCapability ("anti-gravity", null, null);

            var removed_count = 0;
            var disabled_count = 0;

            group.removed.connect (() => {
                removed_count++;
            });

            capability.notify["status"].connect (() => {
                if (capability.status == Pomodoro.CapabilityStatus.DISABLED) {
                    disabled_count++;
                }
            });

            group.add (capability);

            try {
                capability.initialize ();
            }
            catch (GLib.Error error) {
                assert_not_reached ();
            }

            capability.enable ();

            capability = null;
            group = null;

            assert_cmpuint (disabled_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (removed_count, GLib.CompareOperator.EQ, 0);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CapabilityGroupTest ()
    );
}
