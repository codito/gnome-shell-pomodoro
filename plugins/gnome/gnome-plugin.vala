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

    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension, GLib.AsyncInitable
    {
        private Pomodoro.Timer                  timer;
        private GLib.Settings                   settings;
        private Pomodoro.CapabilityGroup        capabilities;
        private GnomePlugin.GnomeShellExtension shell_extension;
        private string                          shell_extension_expected_path;
        private string                          shell_extension_expected_version;
        private GnomePlugin.IdleMonitor         idle_monitor;
        private uint                            become_active_id = 0;
        private bool                            is_gnome = false;
        private double                          last_activity_time = 0.0;
        private Gnome.Shell?                    shell_proxy = null;
        private Gnome.ShellExtensions?          shell_extensions_proxy = null;

        /**
         * Method for enabling extension after install
         */
        private async void enable_extension (GLib.Cancellable? cancellable = null) throws GLib.Error
        {
            if (this.shell_extension.path != shell_extension_expected_path ||
                this.shell_extension.path != shell_extension_expected_version)
            {
                yield this.shell_extension.reload ();
            }

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

        public async void init_shell_extension (GLib.Cancellable? cancellable = null)
        {
            var expected_version = Config.PACKAGE_VERSION;
            var expected_path = Config.EXTENSION_DIR;
            var should_enable = true;

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
                    GLib.warning ("Error while initializing extension: %s", error.message);
                    return;
                }
            }

            this.shell_extension_expected_path = expected_path;
            this.shell_extension_expected_version = expected_version;

            GLib.info ("Extension state=\"%s\" version=\"%s\" path=\"%s\"",
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
                    GLib.warning ("Error while reloading extension: %s", error.message);
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
            this.is_gnome = GLib.Environment.get_variable (CURRENT_DESKTOP_VARIABLE).has_suffix ("GNOME");
            this.settings = Pomodoro.get_settings ().get_child ("preferences");
            this.capabilities = new Pomodoro.CapabilityGroup ("gnome");

            if (!this.is_gnome) {
                return false;
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
                this.settings.get_boolean ("pause-when-idle"))
            {
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
                                       uint                    id)
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
