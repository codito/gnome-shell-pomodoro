/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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


namespace GnomePlugin
{
    /* Least amount of time in seconds between detected events
     * to say that user become active
     */
    private const double IDLE_MONITOR_MIN_IDLE_TIME = 0.5;

    private const string CURRENT_DESKTOP_VARIABLE = "XDG_CURRENT_DESKTOP";

    private const string FLATPAK_DATA_DIR = "/app/share";

    private bool has_prefix (string path,
                             string prefix)
    {
        return File.new_for_path (path).has_prefix (File.new_for_path (prefix));
    }

    private bool has_data_dir (string data_dir)
    {
        foreach (var system_data_dir in GLib.Environment.get_system_data_dirs ())
        {
            if (system_data_dir == data_dir) {
                return true;
            }
        }

        return false;
    }

    private void copy_recursive (GLib.File src,
                                 GLib.File dest,
                                 GLib.FileCopyFlags flags = GLib.FileCopyFlags.NONE,
                                 GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        GLib.FileType src_type = src.query_file_type (GLib.FileQueryInfoFlags.NONE, cancellable);

        if (src_type == GLib.FileType.DIRECTORY) {
            dest.make_directory (cancellable);
            src.copy_attributes (dest, flags, cancellable);

            var src_path = src.get_path ();
            var dest_path = dest.get_path ();
            GLib.FileEnumerator enumerator = src.enumerate_children (GLib.FileAttribute.STANDARD_NAME,
                                                                     GLib.FileQueryInfoFlags.NONE,
                                                                     cancellable);

            for (GLib.FileInfo? info = enumerator.next_file (cancellable); info != null; info = enumerator.next_file (cancellable))
            {
                copy_recursive (
                    GLib.File.new_for_path (GLib.Path.build_filename (src_path, info.get_name ())),
                    GLib.File.new_for_path (GLib.Path.build_filename (dest_path, info.get_name ())),
                    flags,
                    cancellable);
            }
        }
        else if (src_type == GLib.FileType.REGULAR) {
            src.copy (dest, flags, cancellable);
        }
    }

    private void recursively_delete (GLib.File         file,
                                     GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        var file_type = file.query_file_type (GLib.FileQueryInfoFlags.NONE, cancellable);

        if (file_type == GLib.FileType.DIRECTORY) {
            recursively_delete_dir (file, cancellable);
        }
        else {
            file.@delete ();
        }
    }

    private void recursively_delete_dir (GLib.File         directory,
                                         GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        var children = directory.enumerate_children ("standard::name,standard::type",
                                                     GLib.FileQueryInfoFlags.NONE, cancellable);
        GLib.FileInfo? info = null;

        while ((info = children.next_file (cancellable)) != null)
        {
            var type = info.get_file_type ();
            var child = directory.get_child (info.get_name());

            if (type == GLib.FileType.REGULAR) {
                child.@delete (cancellable);
            }
            else if (type == GLib.FileType.DIRECTORY) {
                recursively_delete_dir (child);
            }
        }

        directory.@delete (cancellable);
    }

    /**
     * Safely replace one file with another
     */
    private bool replace_file (GLib.File         source,
                               GLib.File         destination,
                               GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        var backup = destination.get_parent ().get_child (".%s-old".printf (Config.EXTENSION_UUID));  // TODO: generate random name
        var can_restore = false;
        var success = false;

        if (backup.query_exists (cancellable)) {
            recursively_delete (backup, cancellable);
        }

        if (destination.query_exists (cancellable)) {
            can_restore = destination.move (backup, FileCopyFlags.NONE, cancellable);
        }

        if (source.move (destination, FileCopyFlags.NONE, cancellable)) {
            success = true;
            can_restore = false;
            recursively_delete (backup);
        }

        if (can_restore) {
            try {
                backup.move (destination, FileCopyFlags.NONE);  // can't be cancellable
            }
            catch (GLib.Error error) {
                warning ("Error while restoring dir: %s", error.message);
            }
        }

        return success;
    }


// function recursivelyDeleteDir(dir, deleteParent) {
//     let children = dir.enumerate_children('standard::name,standard::type',
//                                           Gio.FileQueryInfoFlags.NONE, null);
//
//     let info;
//     while ((info = children.next_file(null)) != null) {
//         let type = info.get_file_type();
//         let child = dir.get_child(info.get_name());
//         if (type == Gio.FileType.REGULAR)
//             child.delete(null);
//         else if (type == Gio.FileType.DIRECTORY)
//             recursivelyDeleteDir(child, true);
//     }
//
//     if (deleteParent)
//         dir.delete(null);
// }

// function recursivelyMoveDir(srcDir, destDir) {
//     let children = srcDir.enumerate_children('standard::name,standard::type',
//                                              Gio.FileQueryInfoFlags.NONE, null);
//
//     if (!destDir.query_exists(null))
//         destDir.make_directory_with_parents(null);
//
//     let info;
//     while ((info = children.next_file(null)) != null) {
//         let type = info.get_file_type();
//         let srcChild = srcDir.get_child(info.get_name());
//         let destChild = destDir.get_child(info.get_name());
//         if (type == Gio.FileType.REGULAR)
//             srcChild.move(destChild, Gio.FileCopyFlags.NONE, null, null);
//         else if (type == Gio.FileType.DIRECTORY)
//             recursivelyMoveDir(srcChild, destChild);
//     }
// }



    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension, GLib.AsyncInitable
    {
        private Pomodoro.Timer                  timer;
        private GLib.Settings                   settings;
        private Pomodoro.CapabilityGroup        capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private string                          shell_extension_expected_path;
        private string                          shell_extension_expected_version;
        private GnomePlugin.IdleMonitor         idle_monitor;
        private uint32                          become_active_id = 0;
        private bool                            is_gnome = false;
        // private bool                            can_enable = false;
        // private bool                            can_install = false;
        private double                          last_activity_time = 0.0;
        private Gnome.Shell?                    shell_proxy = null;
        private Gnome.ShellExtensions?          shell_extensions_proxy = null;

        // public void ApplicationExtension ()
        // {
        //     // TODO: remove
        //     GLib.debug ("@@@ ApplicationExtension ()");
        //
        //     this.settings = Pomodoro.get_settings ().get_child ("preferences");
        //     this.is_gnome = GLib.Environment.get_variable (CURRENT_DESKTOP_VARIABLE) == "GNOME";
        //     this.capabilities = new Pomodoro.CapabilityGroup ("gnome");
        // }

        /**
         * Extension can't be exported from the Flatpak container. So, we install it to user dir.
         */
        private async void install_extension (string            path,
                                              GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            GLib.warning ("Installing extension…");

            // GLib.File temporary_dir;
            // uint retry = 0;

            // while (true)
            // {
            //     try {
            //         var temporary_path = GLib.DirUtils.make_tmp ("gnome-pomodoro-XXXXXX");
            //         temporary_dir = GLib.File.new_for_path (temporary_path);
            //         break;

                    // temporary_dir = GLib.File.new_for_path (
                    //     Pomodoro.build_tmp_path ("gnome-pomodoro-XXXXXX")
                    // );
                    // yield temporary_dir.make_directory_async (GLib.Priority.DEFAULT, cancellable);
                    // break;

            //     }
            //     catch (GLib.Error error) {
            //         if (retry < 10) {
            //             retry++;
            //         }
            //         else {
            //             GLib.warning ("Failed to create temporary directory: %s", error.message);
            //             throw error;
            //         }
            //     }
            // }

            var success = false;

            var destination_dir = GLib.File.new_for_path (path);
            var source_dir = GLib.File.new_for_path (Config.EXTENSION_DIR);
            var temporary_dir = destination_dir.get_parent ().get_child (".%s".printf (Config.EXTENSION_UUID));  // TODO: generate random name

            // info ("### temporary_dir = %s", temporary_dir.get_path ());
            // info ("### user_data_dir = %s", GLib.Environment.get_user_data_dir ());
            // info ("### PACKAGE_LOCALE_DIR = %s", Config.PACKAGE_LOCALE_DIR);

            if (temporary_dir.query_exists (cancellable)) {
                recursively_delete (temporary_dir);
            }

            // TODO: this part should be async
            copy_recursive (
                source_dir,
                temporary_dir,
                GLib.FileCopyFlags.TARGET_DEFAULT_PERMS,
                cancellable
            );
            copy_recursive (
                GLib.File.new_for_path (Config.PACKAGE_LOCALE_DIR),
                GLib.File.new_for_path (GLib.Path.build_filename (temporary_dir.get_path (), "locale")),
                GLib.FileCopyFlags.TARGET_DEFAULT_PERMS,
                cancellable
            );
            // TODO: compile and install schema?

            try {
                success = replace_file (temporary_dir, destination_dir, cancellable);

                // temporary_dir.move (destination_dir,
                //                     FileCopyFlags.OVERWRITE | FileCopyFlags.TARGET_DEFAULT_PERMS,
                //                     cancellable,
                                    // TODO: handle progress_callback
                //                     () => {});
            }
            catch (GLib.Error error) {
                warning ("Error while moving dir: %s", error.message);
            }

            // TODO: when cancelled, it will override old dir if there was any
            if (success) {
                info ("Moved extension to %s", path);
            }
            else {
                try {
                    recursively_delete (temporary_dir);
                }
                catch (GLib.Error error) {
                    warning ("Failed to cleanup temporary dir: %s", error.message);
                }
            }
        }

        /**
         *
         */
        public bool can_install_extension (string path,
                                           string version)
        {
            if (this.shell_extensions_proxy != null && !this.shell_extensions_proxy.user_extensions_enabled) {
                return false;
            }

            // TODO: check if it's already installed
            // var metadata_file = GLib.Path.build_filename (
            //     path, "metadata.json"
            // );

            // TODO: pomodoro should contain extension .zip file in its datadir, not install extension into /app/share/gnome-shell/...
            // TODO: check if that zipfile exists, not whether we're running from flatpak
            if (!has_data_dir (FLATPAK_DATA_DIR)) {
                return false;
            }

            return true;
        }

        public async void init_shell_extension (GLib.Cancellable? cancellable = null)
        {
            var expected_version = Config.PACKAGE_VERSION;
            var expected_path = Config.EXTENSION_DIR;
            var install_prefix = GLib.Path.build_filename (GLib.Environment.get_home_dir (), ".local");
            var should_enable = true;

            // if (!this.shell_extensions_proxy.user_extensions_enabled) {
            //     // TODO: determine optimal install_prefix,
            //     //       may require sudo to install the extension
            // }

            if (has_prefix (expected_path, FLATPAK_DATA_DIR)) {
                expected_path = GLib.Path.build_filename (
                          install_prefix, "share", "gnome-shell", "extensions",
                          Config.EXTENSION_UUID);
            }

            if (this.shell_extension == null) {
                this.shell_extension = new GnomePlugin.GnomeShellExtension (
                            this.shell_proxy,
                            this.shell_extensions_proxy,
                            Config.EXTENSION_UUID);

                try {
                    // fetch extension state
                    yield this.shell_extension.init_async (GLib.Priority.DEFAULT, cancellable);
                }
                catch (GLib.Error error) {
                    warning ("Error while initializing extension: %s", error.message);
                    return;
                }
            }

            info ("Extension version=\"%s\" path=\"%s\"", this.shell_extension.version, this.shell_extension.path);

            // reload extension if it's not up-to-date,
            // allow extension to be installed in other place than `expected_path`
            if (
                    this.shell_extension.path != expected_path ||
                    this.shell_extension.version != expected_version
            ) {
                try {
                    yield this.shell_extension.reload ();
                }
                catch (GLib.Error error) {
                    warning ("Error while reloading extension: %s", error.message);
                }
            }

            // try to install if missing
            // TODO: ask before installing extension
            if (
                    this.shell_extension.state == Gnome.ExtensionState.UNINSTALLED &&
                    this.can_install_extension (expected_path, expected_version)
            ) {
                try {
                    yield this.install_extension (expected_path, cancellable);
                }
                catch (GLib.Error error) {
                    warning ("Error while installing extension: %s", error.message);
                }
            }

            // notify if extension is outdated
                // TODO: notify if extension is outdated, ask whether to enable it, disable it
                // offer to uninstall it if it's not from expected_path

            // notify if extension does not support gnome-shell version
            if (this.shell_extension.state != Gnome.ExtensionState.OUT_OF_DATE) {
                // TODO: notify if extension is outdated, ask whether to enable it, disable it
            }

            if (should_enable && this.shell_extension.state != Gnome.ExtensionState.ENABLED) {
                yield this.shell_extension.enable (cancellable);
            }
            else if (!should_enable && this.shell_extension.state == Gnome.ExtensionState.ENABLED) {
                yield this.shell_extension.disable (cancellable);
            }

            // TODO: wait until extension initializes its client, registers its capabilities?
            // TODO: monitor gnome-shell mode?
            // TODO: monitor extension state?
        }

        public async bool init_async (int               io_priority = GLib.Priority.DEFAULT,
                                      GLib.Cancellable? cancellable = null)
                                      throws GLib.Error
        {
            this.is_gnome = GLib.Environment.get_variable (CURRENT_DESKTOP_VARIABLE) == "GNOME";
            this.settings = Pomodoro.get_settings ().get_child ("preferences");
            this.capabilities = new Pomodoro.CapabilityGroup ("gnome");

            if (!this.is_gnome) {
                return false; // TODO: what returned false does?
            }

            /* Mutter IdleMonitor */
            if (this.idle_monitor == null) {
                try {
                    // TODO: idle-monitor should be initialized as async
                    this.idle_monitor = new GnomePlugin.IdleMonitor ();

                    this.timer = Pomodoro.Timer.get_default ();
                    this.timer.state_changed.connect_after (this.on_timer_state_changed);

                    this.capabilities.add (new Pomodoro.Capability ("idle-monitor"));
                }
                catch (GLib.Error error) {
                    GLib.debug ("Gnome.IdleMonitor is not available");
                }
            }

            var application = Pomodoro.Application.get_default ();
            application.capabilities.add_group (this.capabilities, Pomodoro.Priority.HIGH);

            // TODO: don't use yield, these can be initialized in parallel
            try {
                this.shell_proxy = yield GLib.Bus.get_proxy<Gnome.Shell> (
                        GLib.BusType.SESSION,
                        "org.gnome.Shell",
                        "/org/gnome/Shell",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                        cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to connect to org.gnome.Shell: %s", error.message);
                throw error;
            }

            try {
                this.shell_extensions_proxy = yield GLib.Bus.get_proxy<Gnome.ShellExtensions> (
                        GLib.BusType.SESSION,
                        "org.gnome.Shell",
                        "/org/gnome/Shell",
                        GLib.DBusProxyFlags.DO_NOT_AUTO_START,
                        cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to connect to org.gnome.Shell.Extensions: %s", error.message);
                throw error;
            }

            /* GNOME Shell extension */
            yield this.init_shell_extension (cancellable);

            return true;
        }

        ~ApplicationExtension ()
        {
            this.timer.state_changed.disconnect (this.on_timer_state_changed);

            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }
        }

        // private void on_shell_mode_changed ()
        // {
            // TODO?
        // }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            if (this.become_active_id != 0) {
                this.idle_monitor.remove_watch (this.become_active_id);
                this.become_active_id = 0;
            }

            if (state is Pomodoro.PomodoroState &&
                previous_state is Pomodoro.BreakState &&
                previous_state.is_completed () &&
                this.settings.get_boolean ("pause-when-idle")
            ) {
                this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);

                this.timer.pause ();
            }
        }

        /**
         * on_become_active callback
         *
         * We want to detect user/human activity so it sparse events.
         */
        private void on_become_active (GnomePlugin.IdleMonitor monitor,
                                       uint32                  id)
        {
            var timestamp = Pomodoro.get_current_time ();

            if (timestamp - this.last_activity_time < IDLE_MONITOR_MIN_IDLE_TIME) {
                this.become_active_id = 0;

                this.timer.resume ();
            }
            else {
                this.become_active_id = this.idle_monitor.add_user_active_watch (this.on_become_active);
            }

            this.last_activity_time = timestamp;
        }
    }

    public class PreferencesDialogExtension : Peas.ExtensionBase, Pomodoro.PreferencesDialogExtension
    {
        private Pomodoro.PreferencesDialog dialog;

        private GLib.Settings settings;
        private GLib.List<Gtk.ListBoxRow> rows;

        construct
        {
            this.settings = new GLib.Settings ("org.gnomepomodoro.Pomodoro.plugins.gnome");
            this.dialog = Pomodoro.PreferencesDialog.get_default ();

            this.setup_main_page ();
        }

        private void setup_main_page ()
        {
            var main_page = this.dialog.get_page ("main") as Pomodoro.PreferencesMainPage;

            var hide_system_notifications_toggle = new Gtk.Switch ();
            hide_system_notifications_toggle.valign = Gtk.Align.CENTER;

            var row = this.create_row (_("Hide other notifications"),
                                       hide_system_notifications_toggle);
            row.name = "hide-system-notifications";
            main_page.lisboxrow_sizegroup.add_widget (row);
            main_page.desktop_listbox.add (row);
            this.rows.prepend (row);

            this.settings.bind ("hide-system-notifications",
                                hide_system_notifications_toggle,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
        }

        ~PreferencesDialogExtension ()
        {
            foreach (var row in this.rows) {
                row.destroy ();
            }

            this.rows = null;
        }

        private Gtk.ListBoxRow create_row (string     label,
                                           Gtk.Widget widget)
        {
            var name_label = new Gtk.Label (label);
            name_label.halign = Gtk.Align.START;
            name_label.valign = Gtk.Align.BASELINE;

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            box.pack_start (name_label, true, true, 0);
            box.pack_start (widget, false, true, 0);

            var row = new Gtk.ListBoxRow ();
            row.activatable = false;
            row.selectable = false;
            row.add (box);
            row.show_all ();

            return row;
        }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.ApplicationExtension),
                                           typeof (GnomePlugin.ApplicationExtension));

    object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                           typeof (GnomePlugin.PreferencesDialogExtension));
}
