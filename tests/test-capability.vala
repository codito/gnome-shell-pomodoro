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
    public class AntiGravityCapability : Pomodoro.Capability
    {
        public uint initialize_count = 0;
        public uint uninitialize_count = 0;
        public uint enable_count = 0;
        public uint disable_count = 0;
        public uint activate_count = 0;

        public AntiGravityCapability (string            name,
                                      Pomodoro.Priority priority = Pomodoro.Priority.DEFAULT)
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


    public class AntiGravityCapabilityTest : Tests.TestSuite
    {
        public AntiGravityCapabilityTest ()
        {
            this.add_test ("initialize", this.test_initialize);
            this.add_test ("uninitialize", this.test_uninitialize);
            this.add_test ("enable", this.test_enable);
            this.add_test ("disable", this.test_disable);
            this.add_test ("activate", this.test_activate);
            this.add_test ("destroy", this.test_destroy);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_initialize ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            capability.initialize ();

            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_cmpuint (capability.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (capability.uninitialize_count, GLib.CompareOperator.EQ, 0);
        }

        public void test_uninitialize ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            capability.initialize ();
            capability.uninitialize ();

            assert_true (capability.status == Pomodoro.CapabilityStatus.NULL);
            assert_cmpuint (capability.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (capability.uninitialize_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_enable ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            capability.initialize ();
            capability.enable ();

            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
            assert_cmpuint (capability.enable_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (capability.disable_count, GLib.CompareOperator.EQ, 0);
        }

        public void test_disable ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            capability.initialize ();
            capability.enable ();
            capability.disable ();

            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_cmpuint (capability.enable_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (capability.disable_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_activate ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            capability.initialize ();
            capability.enable ();
            capability.activate ();

            assert_cmpuint (capability.activate_count, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Expect capability to be disabled during destroy
         */
        public void test_destroy ()
        {
            var capability = new AntiGravityCapability ("anti-gravity");
            capability.initialize ();
            capability.enable ();

            string[] statuses = {};
            capability.notify["status"].connect (() => { statuses += capability.status.to_string (); });

            capability.destroy ();

            assert_cmpstrv (statuses, {
                "disabled",
                "null",
            });
        }
    }


    // public class ExternalCapabilityTest : Tests.TestSuite
    // {
    // }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.AntiGravityCapabilityTest ()
        // new Tests.ExternalCapabilityTest ()
    );
}
