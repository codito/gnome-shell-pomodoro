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
    public Adw.AboutWindow create_about_window ()
    {
        var about_window = new Adw.AboutWindow ();
        about_window.application_icon = "org.gnomepomodoro.Pomodoro";
        about_window.application_name = _("Pomodoro");
        about_window.comments = _("A simple time management utility");
        about_window.version = Config.PACKAGE_VERSION;
        about_window.website = Config.PACKAGE_URL;
        about_window.issue_url = Config.PACKAGE_BUGREPORT;
        about_window.developers = {
            "Arun Mahapatra <pratikarun@gmail.com>",
            "Kamil Prusko <kamilprusko@gmail.com>"
        };
        about_window.translator_credits = _("translator-credits");
        about_window.copyright = "\xc2\xa9 2011-2022 Arun Mahapatra, Kamil Prusko";
        about_window.license_type = Gtk.License.GPL_3_0;

        return about_window;
    }
}
