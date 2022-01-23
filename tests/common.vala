/*
 * Copyright (c) 2014 gnome-pomodoro contributors
 *
 * This code is partly borrowed from libgee's test suite,
 * at https://git.gnome.org/browse/libgee and from gnome-break-timer
 * https://git.gnome.org/browse/gnome-break-timer
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
 */

using GLib;


namespace Tests
{
    public delegate void TestCaseFunc ();

    private string str_to_representation (string value)
    {
        return @"\"$value\"";
    }

    private string strv_to_representation (string[] value)
    {
        var string_builder = new GLib.StringBuilder ("[");
        var length = value.length;

        for (var index = 0; index < length; index++)
        {
            if (index > 0) {
                string_builder.append (", ");
            }
            string_builder.append (str_to_representation (value[index]));
        }

        string_builder.append ("]");

        return string_builder.str;
    }

    public void assert_cmpstrv (string[] value,
                                string[] expected)
    {
        if (GLib.Test.failed ()) {
            return;
        }

        var length = value.length;

        if (length != expected.length)
        {
            GLib.Test.message (
                "Arrays have different length: %s != %s",
                strv_to_representation (value),
                strv_to_representation (expected)
            );
            GLib.Test.fail ();
            return;
        }

        for (var index = 0; index < length; index++)
        {
            if (value[index] != expected[index]) {
                GLib.Test.message (
                    "Arrays are not equal: %s != %s",
                    strv_to_representation (value),
                    strv_to_representation (expected)
                );
                GLib.Test.fail ();
                return;
            }
        }
    }


    /*
    public struct SignalHandlerLogEntry
    {
        public int64               timestamp;
        public unowned GLib.Object instance;
        public string              signal_name;
    }


    public class SignalHandlerLog
    {
        public SignalHandlerLogEntry[] entries;

        public SignalHandlerLog ()
        {
            this.entries = new SignalHandlerLogEntry[0];
            // this.handlers = new GLib.HashTable<str, ulong> ();
        }

        public void clear ()
        {
            this.entries = new SignalHandlerLogEntry[0];
        }

        public void watch (GLib.Object instance,
                           string      signal_name)
        {
            // public unowned GLib.Object instance;
            // this.handlers[signal_name] = this.object.connect (signal_name);

            instance.connect (@"signal::$signal_name", () => {
                message (@"Emitted $signal_name");
            });
        }

        public int count (GLib.Object instance,
                          string      signal_name)
        {
            var count = 0;

            return count;
        }

        // public string[] list (GLib.Object instance)
        // {
        // }
    }
    */


    private class TestCase
    {
        public string name;

        private Tests.TestCaseFunc func;
        private Tests.TestSuite    test_suite;

        public TestCase (string                   name,
                         owned Tests.TestCaseFunc test_case_func,
                         Tests.TestSuite          test_suite)
        {
            this.name       = name;
            this.func       = (owned) test_case_func;
            this.test_suite = test_suite;
        }

        public void setup (void* fixture)
        {
            this.test_suite.setup ();
        }

        public void run (void* fixture)
        {
            this.func ();
        }

        public void teardown (void* fixture)
        {
            this.test_suite.teardown ();
        }

        public GLib.TestCase get_g_test_case ()
        {
            return new GLib.TestCase (this.name,
                                      this.setup,
                                      this.run,
                                      this.teardown);
        }
    }


    public abstract class TestSuite : GLib.Object
    {
        private GLib.TestSuite   g_test_suite;
        private Tests.TestCase[] test_cases = new Tests.TestCase[0];

        construct
        {
            this.g_test_suite = new GLib.TestSuite (this.get_name ());
        }

        public string get_name ()
        {
            return this.get_type ().name ();
        }

        public GLib.TestSuite get_g_test_suite ()
        {
            return this.g_test_suite;
        }

        public void add_test (string                   name,
                              owned Tests.TestCaseFunc func)
        {
            var test_case = new TestCase (name, (owned) func, this);

            this.test_cases += test_case;
            this.g_test_suite.add (test_case.get_g_test_case ());
        }

        public virtual void setup ()
        {
        }

        public virtual void teardown ()
        {
        }
    }


    public static void init (string[] args)
    {
        Gtk.init ();
        GLib.Test.init (ref args);
    }


    public static int run (Tests.TestSuite test_suite, ...)
    {
        var arguments_list = va_list ();
        var root_suite = GLib.TestSuite.get_root ();

        root_suite.add_suite (test_suite.get_g_test_suite ());

        while (true) {
            Tests.TestSuite? extra_test_suite = arguments_list.arg ();
            if (extra_test_suite == null) {
                break;  // end of the list
            }

            root_suite.add_suite (extra_test_suite.get_g_test_suite ());
        }

        return GLib.Test.run ();
    }
}
