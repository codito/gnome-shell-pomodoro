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
    public Gtk.AboutDialog create_about_dialog ()
    {
        var about_dialog = new Gtk.AboutDialog ();
        about_dialog.title = _("About Pomodoro");
        about_dialog.program_name = _("Pomodoro");
        about_dialog.comments = _("A simple time management utility");
        about_dialog.logo_icon_name = "org.gnomepomodoro.Pomodoro";
        about_dialog.version = Config.PACKAGE_VERSION;
        about_dialog.website = Config.PACKAGE_URL;
        about_dialog.authors = {
            "Arun Mahapatra <pratikarun@gmail.com>",
            "Kamil Prusko <kamilprusko@gmail.com>"
        };
        about_dialog.translator_credits = _("translator-credits");
        about_dialog.copyright = "\xc2\xa9 2011-2021 Arun Mahapatra, Kamil Prusko";
        about_dialog.license_type = Gtk.License.GPL_3_0;

        about_dialog.destroy_with_parent = true;
        about_dialog.modal = true;

        return about_dialog;
    }
}
