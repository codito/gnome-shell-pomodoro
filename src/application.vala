/*
 * Copyright (c) 2013-2016 gnome-pomodoro contributors
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
    public interface ApplicationExtension : Peas.ExtensionBase
    {
    }

    internal Gom.Repository get_repository ()
    {
        var application = Pomodoro.Application.get_default ();

        return (Gom.Repository) application.get_repository ();
    }

    public class Application : Gtk.Application
    {
        private const uint REPOSITORY_VERSION = 1;
        private const uint SETUP_PLUGINS_TIMEOUT = 3000;

        public Pomodoro.Service service;
        public Pomodoro.Timer timer;
        public Pomodoro.CapabilityManager capabilities;

        private Gom.Repository repository;
        private Gom.Adapter adapter;

        public GLib.Object get_repository ()
        {
            return (GLib.Object) this.repository;
        }

        private unowned Pomodoro.PreferencesDialog preferences_dialog;
        private unowned Pomodoro.Window window;
        private unowned Gtk.AboutDialog about_dialog;
        private Pomodoro.DesktopExtension desktop_extension;
        private Peas.ExtensionSet extensions;
        private GLib.Settings settings;

        private enum ExitStatus
        {
            UNDEFINED = -1,
            SUCCESS   =  0,
            FAILURE   =  1
        }

        private class Options
        {
            public static bool no_default_window = false;
            public static bool preferences = false;
            public static bool quit = false;
            public static bool start_stop = false;
            public static bool start = false;
            public static bool stop = false;
            public static bool pause_resume = false;
            public static bool pause = false;
            public static bool resume = false;
            public static bool skip = false;
            public static bool extend = false;
            public static bool reset = false;

            public static ExitStatus exit_status = ExitStatus.UNDEFINED;

            public const GLib.OptionEntry[] ENTRIES = {
                { "start-stop", 0, 0, GLib.OptionArg.NONE,
                  ref start_stop, N_("Start/Stop"), null },

                { "start", 0, 0, GLib.OptionArg.NONE,
                  ref start, N_("Start"), null },

                { "stop", 0, 0, GLib.OptionArg.NONE,
                  ref stop, N_("Stop"), null },

                { "pause-resume", 0, 0, GLib.OptionArg.NONE,
                  ref pause_resume, N_("Pause/Resume"), null },

                { "pause", 0, 0, GLib.OptionArg.NONE,
                  ref pause, N_("Pause"), null },

                { "resume", 0, 0, GLib.OptionArg.NONE,
                  ref resume, N_("Resume"), null },

                { "skip", 0, 0, GLib.OptionArg.NONE,
                  ref skip, N_("Skip to a pomodoro or to a break"), null },

                { "extend", 0, 0, GLib.OptionArg.NONE,
                  ref extend, N_("Extend current pomodoro or break"), null },

                { "reset", 0, 0, GLib.OptionArg.NONE,
                  ref reset, N_("Reset current session"), null },

                { "no-default-window", 0, 0, GLib.OptionArg.NONE,
                  ref no_default_window, N_("Run as background service"), null },

                { "preferences", 0, 0, GLib.OptionArg.NONE,
                  ref preferences, N_("Show preferences"), null },

                { "quit", 0, 0, GLib.OptionArg.NONE,
                  ref quit, N_("Quit application"), null },

                { "version", 0, GLib.OptionFlags.NO_ARG, GLib.OptionArg.CALLBACK,
                  (void *) command_line_version_callback, N_("Print version information and exit"), null },

                { null }
            };

            public static void set_defaults ()
            {
                Options.no_default_window = false;
                Options.preferences = false;
                Options.quit = false;
                Options.start_stop = false;
                Options.start = false;
                Options.stop = false;
                Options.pause_resume = false;
                Options.pause = false;
                Options.resume = false;
                Options.skip = false;
                Options.extend = false;
                Options.reset = false;
            }

            public static bool has_timer_option ()
            {
                return Options.start_stop |
                       Options.start |
                       Options.stop |
                       Options.pause_resume |
                       Options.pause |
                       Options.resume |
                       Options.skip |
                       Options.extend |
                       Options.reset;
            }
        }

        public const string[] LEGACY_PLUGINS = { "indicator", "notifications" };


        public Application ()
        {
            GLib.Object (
                application_id: Config.APPLICATION_ID,
                flags: GLib.ApplicationFlags.HANDLES_COMMAND_LINE
            );

            this.timer = null;
            this.service = null;
        }

        public new static unowned Application get_default ()
        {
            return GLib.Application.get_default () as Pomodoro.Application;
        }

        public unowned Gtk.Window get_last_focused_window ()
        {
            unowned List<Gtk.Window> windows = this.get_windows ();

            return windows != null
                    ? windows.first ().data
                    : null;
        }

        private void setup_resources ()
        {
            var display = Gdk.Display.get_default ();

            var css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("/org/gnomepomodoro/Pomodoro/style.css");

            Gtk.StyleContext.add_provider_for_display (
                                           display,
                                           css_provider,
                                           Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var icon_theme = Gtk.IconTheme.get_for_display (display);
            icon_theme.add_resource_path ("/org/gnomepomodoro/Pomodoro/icons");
        }

        private void setup_desktop_extension ()
        {
            try {
                this.desktop_extension = new Pomodoro.DesktopExtension ();

                this.capabilities.add_group (this.desktop_extension.capabilities, Pomodoro.Priority.HIGH);
            }
            catch (GLib.Error error) {
                GLib.warning ("Error while initializing desktop extension: %s",
                              error.message);
            }
        }

        private async void setup_plugins ()
        {
            var engine = Peas.Engine.get_default ();
            engine.add_search_path (Config.PLUGIN_LIB_DIR, Config.PLUGIN_DATA_DIR);

            var timeout_cancellable = new GLib.Cancellable ();
            var timeout_source = (uint) 0;
            var wait_count = 0;

            timeout_source = GLib.Timeout.add (SETUP_PLUGINS_TIMEOUT, () => {
                GLib.debug ("Timeout reached while setting up plugins");

                timeout_source = 0;
                timeout_cancellable.cancel ();

                return GLib.Source.REMOVE;
            });

            this.extensions = new Peas.ExtensionSet (engine, typeof (Pomodoro.ApplicationExtension));
            this.extensions.extension_added.connect ((extension_set,
                                                      info,
                                                      extension_object) => {
                var extension = extension_object as GLib.AsyncInitable;

                if (extension != null)
                {
                    extension.init_async.begin (GLib.Priority.DEFAULT, timeout_cancellable, (obj, res) => {
                        try {
                            extension.init_async.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Failed to initialize plugin \"%s\": %s",
                                          info.get_module_name (),
                                          error.message);
                        }

                        wait_count--;

                        this.setup_plugins.callback ();
                    });

                    wait_count++;
                }
            });

            this.load_plugins ();

            while (wait_count > 0) {
                yield;
            }

            timeout_cancellable = null;

            if (timeout_source != 0) {
                GLib.Source.remove (timeout_source);
            }
        }

        private void setup_capabilities ()
        {
            var default_capabilities = new Pomodoro.CapabilityGroup ("default");

            default_capabilities.add (new Pomodoro.NotificationsCapability ("notifications"));

            this.capabilities = new Pomodoro.CapabilityManager ();
            this.capabilities.add_group (default_capabilities, Pomodoro.Priority.LOW);
        }

        private static bool migrate_repository (Gom.Repository repository,
                                                Gom.Adapter    adapter,
                                                uint           version)
                                                throws GLib.Error
        {
            uint8[] file_contents;
            string error_message;

            GLib.debug ("Migrating database to version %u", version);

            var file = File.new_for_uri (
                "resource:///org/gnomepomodoro/Pomodoro/database/version-%u.sql".printf (version)
            );
            file.load_contents (null, out file_contents, null);

            /* Gom.Adapter.execute_sql is limited to single line queries,
             * so we need to use Sqlite API directly
             */
            unowned Sqlite.Database database = adapter.get_handle ();

            if (database.exec ((string) file_contents, null, out error_message) != Sqlite.OK)
            {
                throw new Gom.Error.COMMAND_SQLITE (error_message);
            }

            return true;
        }

        private void setup_repository ()
        {
            this.hold ();
            this.mark_busy ();

            var path = GLib.Path.build_filename (GLib.Environment.get_user_data_dir (),
                                                 Config.PACKAGE_NAME,
                                                 "database.sqlite");
            var file = GLib.File.new_for_path (path);
            var directory = file.get_parent ();

            if (!directory.query_exists ()) {
                try {
                    directory.make_directory_with_parents ();
                }
                catch (GLib.Error error) {
                    GLib.warning ("Failed to create directory: %s", error.message);
                }
            }

            try {
                /* Open database handle */
                var adapter = new Gom.Adapter ();
                adapter.open_sync (file.get_uri ());
                this.adapter = adapter;

                /* Migrate database if needed */
                var repository = new Gom.Repository (adapter);
                repository.migrate_sync (Pomodoro.Application.REPOSITORY_VERSION,
                                         Pomodoro.Application.migrate_repository);

                this.repository = repository;
            }
            catch (GLib.Error error) {
                GLib.critical ("Failed to migrate database: %s", error.message);
            }

            this.unmark_busy ();
            this.release ();
        }

        private void load_plugins ()
        {
            var engine          = Peas.Engine.get_default ();
            var enabled_plugins = this.settings.get_strv ("enabled-plugins");
            var enabled_hash    = new GLib.HashTable<string, bool> (str_hash, str_equal);

            foreach (var name in enabled_plugins)
            {
                enabled_hash.insert (name, true);
            }

            foreach (var name in LEGACY_PLUGINS)
            {
                enabled_hash.remove (name);
            }

            foreach (var plugin_info in engine.get_plugin_list ())
            {
                if (plugin_info.is_hidden () || enabled_hash.contains (plugin_info.get_module_name ())) {
                    engine.try_load_plugin (plugin_info);
                }
                else {
                    engine.try_unload_plugin (plugin_info);
                }
            }
        }

        public void show_window (string view_name,
                                 uint32 timestamp = 0)
        {
            if (this.window == null)
            {
                var window = new Pomodoro.Window ();
                ((Gtk.Widget) window).destroy.connect (() => {
                    this.window = null;
                });

                this.add_window (window);
                this.window = window;
            }

            this.window.view = Pomodoro.WindowView.from_string (view_name);

            if (timestamp > 0) {
                this.window.present_with_time (timestamp);
            }
            else {
                this.window.present ();
            }
        }

        public void show_preferences (uint32 timestamp = 0)
        {
            if (this.preferences_dialog == null)
            {
                var preferences_dialog = new Pomodoro.PreferencesDialog ();
                ((Gtk.Widget) preferences_dialog).destroy.connect (() => {
                    this.preferences_dialog = null;
                });

                this.add_window (preferences_dialog);
                this.preferences_dialog = preferences_dialog;
            }

            if (timestamp > 0) {
                this.preferences_dialog.present_with_time (timestamp);
            }
            else {
                this.preferences_dialog.present ();
            }
        }

        private void activate_timer (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.show_window ("timer");
        }

        private void activate_stats (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this.show_window ("stats");
        }

        private void activate_preferences (GLib.SimpleAction action,
                                           GLib.Variant?     parameter)
        {
            this.show_preferences ();
        }

        private void activate_visit_website (GLib.SimpleAction action,
                                             GLib.Variant?     parameter)
        {
            try {
                string[] spawn_args = { "xdg-open", Config.PACKAGE_URL };
                string[] spawn_env = GLib.Environ.get ();

                GLib.Process.spawn_async (null,
                                          spawn_args,
                                          spawn_env,
                                          GLib.SpawnFlags.SEARCH_PATH,
                                          null,
                                          null);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn process: %s", error.message);
            }
        }

        private void activate_report_issue (GLib.SimpleAction action,
                                            GLib.Variant?     parameter)
        {
            try {
                string[] spawn_args = { "xdg-open", Config.PACKAGE_BUGREPORT };
                string[] spawn_env = GLib.Environ.get ();

                GLib.Process.spawn_async (null,
                                          spawn_args,
                                          spawn_env,
                                          GLib.SpawnFlags.SEARCH_PATH,
                                          null,
                                          null);
            }
            catch (GLib.SpawnError error) {
                GLib.warning ("Failed to spawn process: %s", error.message);
            }
        }

        private void activate_about (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            if (this.about_dialog == null)
            {
                var about_dialog = Pomodoro.create_about_dialog ();
                ((Gtk.Widget) about_dialog).destroy.connect (() => {
                    this.about_dialog = null;
                });

                if (this.window != null) {
                    about_dialog.set_transient_for (this.window);
                }

                this.add_window (about_dialog);
                this.about_dialog = about_dialog;
            }

            this.about_dialog.present ();
        }

        private void activate_quit (GLib.SimpleAction action,
                                    GLib.Variant?     parameter)
        {
            this.quit ();
        }

        private void activate_timer_skip (GLib.SimpleAction action,
                                          GLib.Variant?     parameter)
        {
            try {
                this.service.skip ();
            }
            catch (GLib.Error error) {
            }
        }

        private void activate_timer_set_state (GLib.SimpleAction action,
                                               GLib.Variant?     parameter)
        {
            try {
                this.service.set_state (parameter.get_string (), 0.0);
            }
            catch (GLib.Error error) {
            }
        }

        private void activate_timer_switch_state (GLib.SimpleAction action,
                                                  GLib.Variant? parameter)
        {
            try {
                this.service.set_state (parameter.get_string (),
                                        this.timer.state.timestamp);
            }
            catch (GLib.Error error) {
            }
        }

        private void setup_actions ()
        {
            GLib.SimpleAction action;

            action = new GLib.SimpleAction ("timer", null);
            action.activate.connect (this.activate_timer);
            this.add_action (action);

            action = new GLib.SimpleAction ("stats", null);
            action.activate.connect (this.activate_stats);
            this.add_action (action);

            action = new GLib.SimpleAction ("preferences", null);
            action.activate.connect (this.activate_preferences);
            this.add_action (action);

            action = new GLib.SimpleAction ("visit-website", null);
            action.activate.connect (this.activate_visit_website);
            this.add_action (action);

            action = new GLib.SimpleAction ("report-issue", null);
            action.activate.connect (this.activate_report_issue);
            this.add_action (action);

            action = new GLib.SimpleAction ("about", null);
            action.activate.connect (this.activate_about);
            this.add_action (action);

            action = new GLib.SimpleAction ("quit", null);
            action.activate.connect (this.activate_quit);
            this.add_action (action);

            action = new GLib.SimpleAction ("timer-skip", null);
            action.activate.connect (this.activate_timer_skip);
            this.add_action (action);

            action = new GLib.SimpleAction ("timer-set-state", GLib.VariantType.STRING);
            action.activate.connect (this.activate_timer_set_state);
            this.add_action (action);

            this.set_accels_for_action ("stats.previous", {"<Alt>Left", "Back"});
            this.set_accels_for_action ("stats.next", {"<Alt>Right", "Forward"});
            this.set_accels_for_action ("app.quit", {"<Primary>q"});
            this.set_accels_for_action ("win.shrink", {"<Primary>space"});
        }

        private static bool command_line_version_callback ()
        {
            stdout.printf ("%s %s\n",
                           GLib.Environment.get_application_name (),
                           Config.PACKAGE_VERSION);

            Options.exit_status = ExitStatus.SUCCESS;

            return true;
        }

        /**
         * Emitted on the primary instance immediately after registration.
         */
        public override void startup ()
        {
            this.hold ();

            base.startup ();

            this.restore_timer ();

            this.setup_resources ();
            this.setup_actions ();
            this.setup_repository ();
            this.setup_capabilities ();
            this.setup_desktop_extension ();
            this.setup_plugins.begin ((obj, res) => {
                this.setup_plugins.end (res);

                GLib.Idle.add (() => {
                    // TODO: shouldn't these be enabled by settings?!
                    this.capabilities.enable ("notifications");
                    this.capabilities.enable ("indicator");
                    this.capabilities.enable ("accelerator");
                    this.capabilities.enable ("hide-system-notifications");
                    this.capabilities.enable ("idle-monitor");

                    this.release ();

                    return GLib.Source.REMOVE;
                });
            });
        }

        /**
         * This is just for local things, like showing help
         */
        private void parse_command_line (ref unowned string[] arguments) throws GLib.OptionError
        {
            var option_context = new GLib.OptionContext ();
            option_context.add_main_entries (Options.ENTRIES, Config.GETTEXT_PACKAGE);

            // TODO: add options from plugins

            option_context.parse (ref arguments);
        }

        protected override bool local_command_line ([CCode (array_length = false, array_null_terminated = true)]
                                                    ref unowned string[] arguments,
                                                    out int              exit_status)
        {
            string[] tmp = arguments;
            unowned string[] arguments_copy = tmp;

            try
            {
                // This is just for local things, like showing help
                this.parse_command_line (ref arguments_copy);
            }
            catch (GLib.Error error)
            {
                stderr.printf ("Failed to parse options: %s\n", error.message);
                exit_status = ExitStatus.FAILURE;

                return true;
            }

            if (Options.exit_status != ExitStatus.UNDEFINED)
            {
                exit_status = Options.exit_status;

                return true;
            }

            return base.local_command_line (ref arguments, out exit_status);
        }

        public override int command_line (GLib.ApplicationCommandLine command_line)
        {
            string[] tmp = command_line.get_arguments ();
            unowned string[] arguments_copy = tmp;

            var exit_status = ExitStatus.SUCCESS;

            do {
                try
                {
                    this.parse_command_line (ref arguments_copy);
                }
                catch (GLib.Error error)
                {
                    stderr.printf ("Failed to parse options: %s\n", error.message);

                    exit_status = ExitStatus.FAILURE;
                    break;
                }

                if (Options.exit_status != ExitStatus.UNDEFINED)
                {
                    exit_status = Options.exit_status;
                    break;
                }

                this.activate ();
            }
            while (false);

            return exit_status;
        }

        /* Save the state before exit.
         *
         * Emitted only on the registered primary instance immediately after
         * the main loop terminates.
         */
        public override void shutdown ()
        {
            this.hold ();

            this.save_timer ();

            foreach (var window in this.get_windows ()) {
                this.remove_window (window);
            }

            this.capabilities.disable_all ();

            var engine = Peas.Engine.get_default ();

            foreach (var plugin_info in engine.get_plugin_list ()) {
                engine.try_unload_plugin (plugin_info);
            }

            try {
                if (this.adapter != null) {
                    this.adapter.close_sync ();
                }
            }
            catch (GLib.Error error) {
            }

            base.shutdown ();

            this.release ();
        }

        /* Emitted on the primary instance when an activation occurs.
         * The application must be registered before calling this function.
         */
        public override void activate ()
        {
            this.hold ();

            Options.no_default_window |= Options.has_timer_option ();

            if (Options.quit) {
                this.quit ();
            }
            else {
                if (Options.reset) {
                    this.timer.reset ();
                }

                if (Options.start_stop) {
                    this.timer.toggle ();
                }
                else if (Options.start) {
                    this.timer.start ();
                }
                else if (Options.stop) {
                    this.timer.stop ();
                }

                if (Options.skip) {
                    this.timer.skip ();
                }
                else if (Options.extend && this.timer.state.duration > 0.0) {
                    this.timer.state.duration += 60.0;
                }

                if (Options.pause_resume) {
                    if (this.timer.is_paused) {
                        this.timer.resume ();
                    }
                    else {
                        this.timer.pause ();
                    }
                }
                else if (Options.pause) {
                    this.timer.pause ();
                }
                else if (Options.resume) {
                    this.timer.resume ();
                }

                if (Options.preferences) {
                    this.show_preferences ();
                }
                else if (!Options.no_default_window) {
                    this.show_window ("default");
                }

                Options.set_defaults ();
            }

            this.release ();
        }

        public override bool dbus_register (GLib.DBusConnection connection,
                                            string              object_path) throws GLib.Error
        {
            if (!base.dbus_register (connection, object_path)) {
                return false;
            }

            if (this.timer == null) {
                this.timer = Pomodoro.Timer.get_default ();
                this.timer.notify["is-paused"].connect (this.on_timer_is_paused_notify);
                this.timer.state_changed.connect_after (this.on_timer_state_changed);
            }

            if (this.settings == null) {
                this.settings = Pomodoro.get_settings ()
                                        .get_child ("preferences");
                this.settings.changed.connect (this.on_settings_changed);
            }

            if (this.service == null) {
                this.hold ();
                this.service = new Pomodoro.Service (connection, this.timer);

                try {
                    connection.register_object ("/org/gnomepomodoro/Pomodoro", this.service);
                }
                catch (GLib.IOError error) {
                    GLib.warning ("%s", error.message);
                    return false;
                }
            }

            return true;
        }

        public override void dbus_unregister (GLib.DBusConnection connection,
                                              string              object_path)
        {
            base.dbus_unregister (connection, object_path);

            if (this.timer != null) {
                this.timer.destroy ();
                this.timer = null;
            }

            if (this.service != null) {
                this.service = null;

                this.release ();
            }
        }

        private void save_timer ()
        {
            var state_settings = Pomodoro.get_settings ()
                                         .get_child ("state");

            this.timer.save (state_settings);
        }

        private void restore_timer ()
        {
            var state_settings = Pomodoro.get_settings ()
                                         .get_child ("state");

            this.timer.restore (state_settings);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            var state_duration = this.timer.state_duration;

            switch (key)
            {
                case "pomodoro-duration":
                    if (this.timer.state is Pomodoro.PomodoroState) {
                        state_duration = settings.get_double (key);
                    }
                    break;

                case "short-break-duration":
                    if (this.timer.state is Pomodoro.ShortBreakState) {
                        state_duration = settings.get_double (key);
                    }
                    break;

                case "long-break-duration":
                    if (this.timer.state is Pomodoro.LongBreakState) {
                        state_duration = settings.get_double (key);
                    }
                    break;

                case "enabled-plugins":
                    this.load_plugins ();

                    break;
            }

            if (state_duration != this.timer.state_duration)
            {
                this.timer.state_duration = double.max (state_duration, this.timer.elapsed);
            }
        }

        private void on_timer_is_paused_notify ()
        {
            this.save_timer ();
        }

        /**
         * Save timer state, assume user is idle when break is completed.
         */
        private void on_timer_state_changed (Pomodoro.Timer      timer,
                                             Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            this.hold ();
            this.save_timer ();

            if (this.timer.is_paused)
            {
                this.timer.resume ();
            }

            if (!(previous_state is Pomodoro.DisabledState))
            {
                var entry = new Pomodoro.Entry.from_state (previous_state);
                entry.repository = this.repository;
                entry.save_async.begin ((obj, res) => {
                    try {
                        entry.save_async.end (res);
                    }
                    catch (GLib.Error error) {
                        GLib.warning ("Error while saving entry: %s", error.message);
                    }

                    this.release ();
                });
            }
        }
    }
}
