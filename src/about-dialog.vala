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
        var dialog = new Gtk.AboutDialog ();
        dialog.title = _("About Pomodoro");
        dialog.program_name = _("Pomodoro");
        dialog.comments = _("A simple time management utility");
        dialog.logo_icon_name = "org.gnomepomodoro.Pomodoro";
        dialog.version = Config.PACKAGE_VERSION;
        dialog.website = Config.PACKAGE_URL;
        dialog.authors = {
            "Arun Mahapatra <pratikarun@gmail.com>",
            "Kamil Prusko <kamilprusko@gmail.com>"
        };
        dialog.translator_credits = _("translator-credits");
        dialog.copyright = "\xc2\xa9 2011-2021 Arun Mahapatra, Kamil Prusko";
        dialog.license_type = Gtk.License.GPL_3_0;

        dialog.destroy_with_parent = true;
        dialog.modal = true;

        return dialog;
    }
}
