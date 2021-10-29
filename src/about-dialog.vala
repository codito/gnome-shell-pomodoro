/*
 * Copyright (c) 2013 gnome-pomodoro contributors
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

using GLib;


namespace Pomodoro
{
    public class AboutDialog : Gtk.AboutDialog
    {
        public AboutDialog ()
        {
            this.title = _("About Pomodoro");
            this.program_name = _("Pomodoro");
            this.comments = _("A simple time management utility");
            this.logo_icon_name = Config.PACKAGE_NAME;
            this.version = Config.PACKAGE_VERSION;
            this.website = Config.PACKAGE_URL;

            this.authors = {
                "Arun Mahapatra <pratikarun@gmail.com>",
                "Kamil Prusko <kamilprusko@gmail.com>"
            };
            this.translator_credits = _("translator-credits");
            this.copyright = "Copyright \xc2\xa9 2011-2021 Arun Mahapatra, Kamil Prusko";
            this.license_type = Gtk.License.GPL_3_0;

            this.destroy_with_parent = true;
            this.modal = true;
        }
    }
}
