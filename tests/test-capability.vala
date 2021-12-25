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
    public class CapabilityTest : Tests.TestSuite
    {
        private int enable_count;
        private int disable_count;

        public CapabilityTest ()
        {
            this.add_test ("enable",
                           this.test_enable);

            this.add_test ("disable",
                           this.test_disable);

            this.add_test ("dispose",
                           this.test_dispose);
        }

        public override void setup ()
        {
            this.enable_count = 0;
            this.disable_count = 0;
        }

        public override void teardown ()
        {
        }

        private void handle_capability_enable (Pomodoro.Capability capability)
        {
            this.enable_count++;
        }

        private void handle_capability_disable (Pomodoro.Capability capability)
        {
            this.disable_count++;
        }

        /**
         * Unit test for Pomodoro.Capability.enable() method.
         */
        public void test_enable ()
        {
            var capability = new Pomodoro.Capability ("anti-gravity",
                                                      this.handle_capability_enable,
                                                      this.handle_capability_disable);

            capability.enable ();

            assert (capability.enabled);
            assert (this.enable_count == 1);
            assert (this.disable_count == 0);
        }

        /**
         * Unit test for Pomodoro.Capability.disable() method.
         */
        public void test_disable ()
        {
            var capability = new Pomodoro.Capability ("anti-gravity",
                                                      this.handle_capability_enable,
                                                      this.handle_capability_disable);
            capability.enable ();
            capability.disable ();

            assert (!capability.enabled);
            assert (this.enable_count == 1);
            assert (this.disable_count == 1);
        }

        /**
         * Unit test for Pomodoro.Capability.dispose() method.
         */
        public void test_dispose ()
        {
            var capability = new Pomodoro.Capability ("anti-gravity",
                                                      this.handle_capability_enable,
                                                      this.handle_capability_disable);
            capability.enable ();

            capability = null;

            assert (this.enable_count == 1);
            assert (this.disable_count == 1);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CapabilityTest ()
    );
}
