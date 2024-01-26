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
    [Flags]
    public enum Scenario
    {
        DEFAULT,
        UNAVAILABLE
    }


    public class AntiGravityCapability : Pomodoro.Capability
    {
        public uint initialize_count = 0;
        public uint uninitialize_count = 0;
        public uint enable_count = 0;
        public uint disable_count = 0;
        public uint activate_count = 0;

        public AntiGravityCapability (string                      name,
                                      Pomodoro.CapabilityPriority priority = Pomodoro.CapabilityPriority.DEFAULT)
        {
            base (name, priority);
        }

        public override void initialize ()
        {
            this.initialize_count++;

            base.initialize ();
        }

        public override void uninitialize ()
        {
            this.uninitialize_count++;

            base.uninitialize ();
        }

        public override void enable ()
        {
            this.enable_count++;

            base.enable ();
        }

        public override void disable ()
        {
            this.disable_count++;

            base.disable ();
        }

        public override void activate ()
        {
            this.activate_count++;
        }
    }


    public class CapabilityManagerTest : Tests.TestSuite
    {
        public CapabilityManagerTest ()
        {
            this.add_test ("register", this.test_register);
            this.add_test ("enable__before_register", this.test_enable__before_register);

            // TODO: write more tests
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_register ()
        {
            var manager = new Pomodoro.CapabilityManager ();

            var capability_1 = new AntiGravityCapability ("anti-gravity");
            assert_true (capability_1.status == Pomodoro.CapabilityStatus.NULL);
            assert_false (manager.is_enabled ("anti-gravity"));

            manager.register (capability_1);
            assert_false (manager.is_enabled ("anti-gravity"));
            assert_true (capability_1.status == Pomodoro.CapabilityStatus.DISABLED);
        }

        public void test_enable__before_register ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            manager.enable ("anti-gravity");
            assert_false (manager.is_enabled ("anti-gravity"));

            manager.register (capability);
            assert_true (manager.is_enabled ("anti-gravity"));
            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CapabilityManagerTest ()
    );
}
