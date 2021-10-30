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

    private string generate_random_string (uint   length,
                                           uint32 seed = 0)
    {
        var string_builder = new GLib.StringBuilder.sized (length);
        GLib.Rand random;

        if (seed != 0) {
            random = new GLib.Rand.with_seed (seed);
        }
        else {
            random = new GLib.Rand ();
        }

        for (var index = 0; index < length; index++)
        {
            var random_value = (uint8) random.int_range (0, 36);

            string_builder.append_c ((char) ((random_value <= 9 ? 48 : 87) + random_value));
        }

        return string_builder.str;
    }

    private bool recursively_copy (GLib.File          source,
                                   GLib.File          destination,
                                   GLib.FileCopyFlags flags = GLib.FileCopyFlags.NONE,
                                   GLib.Cancellable?  cancellable = null) throws GLib.Error
    {
        destination.make_directory (cancellable);
        source.copy_attributes (destination, flags, cancellable);

        var children = source.enumerate_children ("standard::name,standard::type",
                                                  GLib.FileQueryInfoFlags.NONE,
                                                  cancellable);
        for (GLib.FileInfo? info = children.next_file (cancellable);
             info != null;
             info = children.next_file (cancellable))
        {
            var type = info.get_file_type ();
            var source_child = source.get_child (info.get_name ());
            var destination_child = destination.get_child (info.get_name ());

            if (type == GLib.FileType.DIRECTORY) {
                recursively_copy (source_child, destination_child, flags, cancellable);
            }
            else {
                source_child.copy (destination_child, flags, cancellable);
            }
        }

        return cancellable == null || !cancellable.is_cancelled ();
    }

    private void recursively_delete (GLib.File         directory,
                                     GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        var children = directory.enumerate_children ("standard::name,standard::type",
                                                     GLib.FileQueryInfoFlags.NONE, cancellable);
        GLib.FileInfo? info = null;

        while ((info = children.next_file (cancellable)) != null)
        {
            var type = info.get_file_type ();
            var child = directory.get_child (info.get_name());

            if (type == GLib.FileType.DIRECTORY) {
                recursively_delete (child);
            }
            else {
                child.@delete (cancellable);
            }
        }

        directory.@delete (cancellable);
    }

    /**
     * Safely replace one dir with another
     */
    // TODO: should be async
    private bool replace_dir (GLib.File         source,
                              GLib.File         destination,
                              GLib.Cancellable? cancellable = null) throws GLib.Error
    {
        var backup = destination.get_parent ().get_child (
            ".%s.%s".printf (destination.get_basename (), generate_random_string (12)));
        var can_restore = false;
        var success = false;

        if (backup.query_exists (cancellable)) {
            recursively_delete (backup, cancellable);
        }

        if (destination.query_exists (cancellable)) {
            can_restore = destination.move (backup, FileCopyFlags.NONE, cancellable);
        }

        try {
            if (recursively_copy (source, destination, FileCopyFlags.TARGET_DEFAULT_PERMS, cancellable)) {
                success = true;
                recursively_delete (source);

                if (can_restore) {
                    recursively_delete (backup);
                    can_restore = false;
                }
            }
        }
        finally {
            if (can_restore) {
                try {
                    backup.move (destination, FileCopyFlags.NONE);
                }
                catch (GLib.Error error) {
                    warning ("Error while restoring dir: %s", error.message);
                }
            }
        }

        return success;
    }

    // private void open_extensions_app ()
    // {
    //     try {
    //         string[] spawn_args = { "gnome-shell-extension-prefs", };
    //         string[] spawn_env = GLib.Environ.get ();

    //         GLib.Process.spawn_async (null,
    //                                   spawn_args,
    //                                   spawn_env,
    //                                   GLib.SpawnFlags.SEARCH_PATH,
    //                                   null,
    //                                   null);
    //     }
    //     catch (GLib.SpawnError error) {
    //         GLib.warning ("Failed to spawn process: %s", error.message);
    //     }
    // }

    // public async void sleep (uint              interval,
    //                          int               priority = GLib.Priority.DEFAULT,
    //                          GLib.Cancellable? cancellable = null)
    // {
    //     GLib.Timeout.add (interval, () => {
    //         sleep.callback ();
    //         return false;
    //     }, priority);
    //
    //     yield;
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
        private double                          last_activity_time = 0.0;
        private Gnome.Shell?                    shell_proxy = null;
        private Gnome.ShellExtensions?          shell_extensions_proxy = null;
        private bool                            install_extension_notification_dismissed = false;


        /**
         * Extension can't be exported from the Flatpak container. So, we install it to user dir.
         */
        private async void install_extension (string            path,
                                              GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            GLib.info ("Installing extension…");

            var destination_dir = GLib.File.new_for_path (path);
            var source_dir = GLib.File.new_for_path (Config.EXTENSION_DIR);
            var temporary_dir = GLib.File.new_for_path (
                GLib.Path.build_filename (GLib.Environment.get_tmp_dir (), destination_dir.get_basename ())
            );
            var success = false;

            // TODO: remove
            // yield sleep (3000, GLib.Priority.DEFAULT, cancellable);

            if (temporary_dir.query_exists (cancellable)) {
                recursively_delete (temporary_dir);
            }

            // TODO: this part should be async
            recursively_copy (
                source_dir,
                temporary_dir,
                GLib.FileCopyFlags.TARGET_DEFAULT_PERMS,
                cancellable
            );
            recursively_copy (
                GLib.File.new_for_path (Config.PACKAGE_LOCALE_DIR),
                GLib.File.new_for_path (GLib.Path.build_filename (temporary_dir.get_path (), "locale")),
                GLib.FileCopyFlags.TARGET_DEFAULT_PERMS,
                cancellable
            );
            // TODO: compile and install schema?

            try {
                success = replace_dir (temporary_dir, destination_dir, cancellable);
            }
            catch (GLib.Error error) {
                warning ("Error while moving dir: %s", error.message);
            }

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
         * Method for enabling extension after install
         */
        private async void enable_extension (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            yield this.shell_extension.reload ();
            yield this.shell_extension.enable ();
        }

        /**
         * Read extension version from metadata.json
         */
        private string get_extension_version (string extension_path)
        {
            var metadata_path = GLib.Path.build_filename (extension_path, "metadata.json");
            var parser = new Json.Parser ();

            try {
	            parser.load_from_file (metadata_path);

	            var data = parser.get_root ().get_object ();

                if (data != null) {
                    return data.get_string_member_with_default ("version", "");
                }
            }
            catch (GLib.FileError.NOENT error) {
                // ignore when file does not exist
            }
            catch (GLib.Error error) {
	            warning ("Error while parsing file %s: %s\n", extension_path, error.message);
            }

            return "";
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

            if (this.get_extension_version (path) == version) {
                // already installed
                return false;
            }

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

            this.shell_extension_expected_path = expected_path;
            this.shell_extension_expected_version = expected_version;

            info ("Extension state=\"%s\" version=\"%s\" path=\"%s\"",
                  this.shell_extension.state.to_string (), this.shell_extension.version, this.shell_extension.path);

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

            /*
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

            */
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

            // TODO: wait until extension to register a service over D-Bus?

            /* Pomodoro Window */
            application.window_added.connect (this.on_window_added);
            application.get_windows ().@foreach (this.on_window_added);

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

        private void on_install_extension_notification_clicked ()
        {
            var cancellable = new GLib.Cancellable ();
            var application = Pomodoro.Application.get_default ();
            var window = application.get_last_focused_window ();

            var dialog = new Pomodoro.InstallExtensionDialog ();
            dialog.set_transient_for ((Gtk.Window?) window);

            // delay installing to show progress
            GLib.Timeout.add (500, () => {
                if (cancellable.is_cancelled ()) {
                    return GLib.Source.REMOVE;
                }

                this.install_extension.begin (this.shell_extension_expected_path, cancellable, (object, result) => {
                    try {
                        this.install_extension.end (result);

                        // if (this.shell_extension.path != "") {

                        this.enable_extension.begin (cancellable, (object_, result_) => {
                            try {
                                this.enable_extension.end (result_);
                                dialog.show_success_page ();
                            }
                            catch (GLib.Error error) {
                                warning ("Error while enabling extension: %s", error.message);
                                dialog.show_enabling_error_page (error.message);
                            }
                        });
                    }
                    catch (GLib.Error error) {
                        warning ("Error while installing extension: %s", error.message);
                        dialog.show_error_page (error.message);
                    }
                });

                if (cancellable.is_cancelled ()) {
                    dialog.close ();
                }

                return GLib.Source.REMOVE;
            });

            dialog.response.connect ((response_id) => {
                switch (response_id)
                {
                    case Gtk.ResponseType.DELETE_EVENT:
                        cancellable.cancel ();
                        break;

                    case Pomodoro.InstallExtensionDialogResponse.CANCEL:
                        cancellable.cancel ();
                        dialog.close ();
                        break;

                    case Pomodoro.InstallExtensionDialogResponse.CLOSE:
                        dialog.close ();
                        break;

                    case Pomodoro.InstallExtensionDialogResponse.MANAGE_EXTENSIONS:
                        this.shell_extension.show_preferences ();
                        dialog.close ();
                        break;

                    case Pomodoro.InstallExtensionDialogResponse.REPORT_ISSUE:
                        application.activate_action ("report-issue", null);
                        dialog.close ();
                        break;

                    default:
                        warning ("Dialog response %d not handled", response_id);
                        break;
                }
            });
            dialog.close.connect (() => {
                cancellable.cancel ();
            });

            dialog.run ();
        }

        private void on_install_extension_notification_dismissed (Gtk.Widget widget)
        {
            this.install_extension_notification_dismissed = true;
        }

        private void update_window (Pomodoro.Window window)
        {
            if (
                    !this.install_extension_notification_dismissed &&
                    // this.shell_extension.state == Gnome.ExtensionState.UNINSTALLED &&
                    this.can_install_extension (this.shell_extension_expected_path, this.shell_extension_expected_version)
            ) {
                window.show_in_app_notification_install_extension (
                    on_install_extension_notification_clicked,
                    on_install_extension_notification_dismissed);
            }
            else {
                window.hide_in_app_notification_install_extension ();
            }
        }

        private void on_window_added (Gtk.Window window)
        {
            if (window is Pomodoro.Window) {
                GLib.debug ("on_window_added()");

                var state_changed_id = this.shell_extension.state_changed.connect (() => {
                    this.update_window (window as Pomodoro.Window);
                });

                window.destroy.connect (() => {
                    window.disconnect (state_changed_id);
                });

                this.update_window (window as Pomodoro.Window);
            }
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
