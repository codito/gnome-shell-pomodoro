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
        NONE,
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
            // this.add_test ("register__enabled", this.test_register__enabled);
            // this.add_test ("unregister", this.test_unregister);

            // this.add_test ("register_group", this.test_register_group);
            // this.add_test ("unregister_group", this.test_unregister_group);

            // this.add_test ("enable", this.test_enable);
            // this.add_test ("enable_2", this.test_enable_2);
            // this.add_test ("enable_3", this.test_enable_3);
            // this.add_test ("fallback_register_group", this.test_fallback_register_group);
            // this.add_test ("fallback_unregister_group", this.test_fallback_unregister_group);
            // this.add_test ("fallback_capability_added", this.test_fallback_capability_added);
            // this.add_test ("fallback_capability_removed", this.test_fallback_capability_removed);
            // this.add_test ("dispose", this.test_dispose);
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
            assert_false (manager.is_enable_scheduled ("anti-gravity"));

            manager.register (capability_1);
            assert_false (manager.is_enable_scheduled ("anti-gravity"));
            assert_true (capability_1.status == Pomodoro.CapabilityStatus.DISABLED);
        }

        // public void test_register ()
        // {
        //     var capability = new Pomodoro.AntiGravityCapability ("anti-gravity");
        //     var manager    = new Pomodoro.CapabilityManager ();

        //     capability.enable ();
        //     assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);

        //     manager.register (capability);
        //     assert_true (manager.is_enable_scheduled ("anti-gravity"));
        //     assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
        // }

        public void test_enable__before_register ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            manager.enable ("anti-gravity");
            assert_true (manager.is_enable_scheduled ("anti-gravity"));

            manager.register (capability);
            assert_true (manager.is_enable_scheduled ("anti-gravity"));
            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
        }

        // public void test_inherit_priority ()
        // {
        // }

    /*
        public void test_enable ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            manager.enable ("anti-gravity");
            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);

            manager.disable ("anti-gravity");
            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
        }

         Test if initial "enabled" value is handled by manager.
        public void test_enable_2 ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            capability.enable ();

            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
        }

         Test if "enabled" value is saved independently from Capability.enabled.
        public void test_enable_3 ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            manager.enable ("anti-gravity");

            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
        }

        public void test_fallback_add_group ()
        {
            var manager = new Pomodoro.CapabilityManager ();

            var capability_1 = new AntiGravityCapability ("anti-gravity");
            var capability_2 = new AntiGravityCapability ("anti-gravity");

            manager.register_group (group_1, Pomodoro.CapabilityPriority.DEFAULT);
            manager.register_group (group_2, Pomodoro.CapabilityPriority.HIGH);

            manager.enable ("anti-gravity");

            assert_true (manager.get_preferred_capability ("anti-gravity") == capability_2);
            assert_true (capability_2 == Pomodoro.CapabilityStatus.ENABLED);
            assert_true (capability_1 == Pomodoro.CapabilityStatus.DISABLED);
        }

        public void test_fallback_remove_group ()
        {
            var manager = new Pomodoro.CapabilityManager ();

            var capability_1 = new AntiGravityCapability ("anti-gravity");
            var capability_2 = new AntiGravityCapability ("anti-gravity");

            manager.register_group (group_1, Pomodoro.CapabilityPriority.DEFAULT);
            manager.register_group (group_2, Pomodoro.CapabilityPriority.HIGH);

            manager.enable ("anti-gravity");

            assert_true (manager.get_preferred_capability ("anti-gravity") == capability_2);
            assert_true (capability_2 == Pomodoro.CapabilityStatus.ENABLED);
            assert_true (capability_1 == Pomodoro.CapabilityStatus.DISABLED);

            manager.remove (group_2);
            assert_true (manager.get_preferred_capability ("anti-gravity") == capability_1);
            assert_true (capability_2 == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_1 == Pomodoro.CapabilityStatus.ENABLED);
        }

        public void test_fallback_capability_added ()
        {
            var manager = new Pomodoro.CapabilityManager ();

            var capability_1 = new AntiGravityCapability ("anti-gravity");

            var capability_2 = new AntiGravityCapability ("anti-gravity");

            manager.register_group (group_1, Pomodoro.CapabilityPriority.DEFAULT);
            manager.register_group (group_2, Pomodoro.CapabilityPriority.HIGH);

            manager.enable ("anti-gravity");

            assert_true (manager.get_preferred_capability ("anti-gravity") == capability_2);
            assert_true (capability_2 == Pomodoro.CapabilityStatus.ENABLED);
            assert_true (capability_1 == Pomodoro.CapabilityStatus.DISABLED);
        }

        public void test_fallback_capability_removed ()
        {
            var manager = new Pomodoro.CapabilityManager ();

            var capability_1 = new AntiGravityCapability ("anti-gravity");
            var capability2 = new AntiGravityCapability ("anti-gravity");

            manager.register_group (group_1, Pomodoro.CapabilityPriority.DEFAULT);
            manager.register_group (group_2, Pomodoro.CapabilityPriority.HIGH);

            manager.enable ("anti-gravity");

            assert_true (manager.get_preferred_capability ("anti-gravity") == capability2);
            assert_true (capability_2 == Pomodoro.CapabilityStatus.ENABLED);
            assert_true (capability_1 == Pomodoro.CapabilityStatus.DISABLED);

            group2.remove ("anti-gravity");
            assert_true (manager.get_preferred_capability ("anti-gravity") == capability_1);
            assert_true (capability_2 == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_1 == Pomodoro.CapabilityStatus.ENABLED);
        }

        public void test_dispose ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            var manager    = new Pomodoro.CapabilityManager ();

            manager.enable ("anti-gravity");

            manager.dispose ();

            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
        }
        */
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CapabilityManagerTest ()
    );
}
