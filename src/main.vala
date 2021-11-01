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


private Pomodoro.Application application;


private void on_posix_signal (int signal)
{
    switch (signal)
    {
        case Posix.Signal.INT:
        case Posix.Signal.TERM:
            application.quit ();
            break;

        default:
            break;
    }
}


public int main (string[] args)
{
    var exit_status = 0;

    Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.PACKAGE_LOCALE_DIR);
    Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    GLib.Environment.set_application_name (_("Pomodoro"));
    GLib.Environment.set_prgname (Config.PACKAGE_NAME);

    application = new Pomodoro.Application ();

    /* register unix signal handler */
    Posix.signal (Posix.Signal.INT, on_posix_signal);
    Posix.signal (Posix.Signal.TERM, on_posix_signal);

    return application.run (args);
}
