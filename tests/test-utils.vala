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
    public class UtilsTest : Tests.TestSuite
    {
        public UtilsTest ()
        {
            this.add_test ("build_tmp_path",
                           this.test_build_tmp_path);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        /**
         * Unit test for build_tmp_path() function.
         */
        public void test_build_tmp_path ()
        {
            var prefix_dir = File.new_for_path (
                GLib.Environment.get_tmp_dir ()
            );

            for (var seed=1; seed < 100; seed++) {
                var dir = File.new_for_path (
                    Pomodoro.build_tmp_path ("gnome-pomodoro-XXXXXX", seed)
                );
                assert (dir.has_prefix (prefix_dir));

                var basename = dir.get_basename ();
                assert (basename.substring (0, 15) == "gnome-pomodoro-");

                int index = 15;
                unichar character;
                while (basename.get_next_char (ref index, out character)) {
                    assert (character.validate () && character.isalnum ());
                }
            }
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.UtilsTest ()
    );
}
