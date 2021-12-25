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
            this.add_test ("add",
                           this.test_add);

            this.add_test ("remove",
                           this.test_remove);

            this.add_test ("dispose",
                           this.test_dispose);
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

            var group      = new Pomodoro.CapabilityGroup ();
            var capability = new Pomodoro.Capability ("anti-gravity");

            group.capability_added.connect (() => {
                signal_emit_count++;
            });

            group.add (capability);

            assert (group.contains ("anti-gravity"));
            assert (signal_emit_count == 1);
        }

        /**
         * Unit test for Pomodoro.CapabilityGroup.remove() method.
         */
        public void test_remove ()
        {
            var signal_emit_count = 0;

            var group      = new Pomodoro.CapabilityGroup ();
            var capability = new Pomodoro.Capability ("anti-gravity");

            group.capability_removed.connect (() => {
                signal_emit_count++;
            });

            group.add (capability);
            group.remove ("anti-gravity");

            assert (!group.contains ("anti-gravity"));
            assert (signal_emit_count == 1);
        }

        /**
         * Unit test for Pomodoro.CapabilityGroup.dispose() method.
         */
        public void test_dispose ()
        {
            var capability_removed_count = 0;
            var capability_disabled_count = 0;

            var group      = new Pomodoro.CapabilityGroup ();
            var capability = new Pomodoro.Capability ("anti-gravity");

            group.capability_removed.connect (() => {
                capability_removed_count++;
            });

            capability.disable.connect (() => {
                capability_disabled_count++;
            });

            group.add (capability);
            capability.enable ();

            capability = null;
            group = null;

            assert (capability_disabled_count == 1);
            assert (capability_removed_count == 0);
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
