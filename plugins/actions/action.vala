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
 */

using GLib;


namespace Actions
{
    public class Action : GLib.Object
    {
        public string name { get; set; }
        public string command {
            get {
                return this._command;
            }
            set {
                this._command = value;

                this.validate_command ();
            }
        }
        public string path {
            owned get {
                return this.settings != null ? this.settings.path : null;
            }
            construct set {
                if (value != null) {
                    this.settings = new Settings.with_path ("org.gnomepomodoro.Pomodoro.plugins.actions.action",
                                                            value);

                    this.settings.bind ("name",
                                        this,
                                        "name",
                                        GLib.SettingsBindFlags.DEFAULT);
                    this.settings.bind ("command",
                                        this,
                                        "command",
                                        GLib.SettingsBindFlags.DEFAULT);
                    this.settings.bind ("states",
                                        this,
                                        "states",
                                        GLib.SettingsBindFlags.DEFAULT);
                    this.settings.bind ("triggers",
                                        this,
                                        "triggers",
                                        GLib.SettingsBindFlags.DEFAULT);
                }
                else {
                    this.settings = null;
                }
            }
        }
        public Actions.State states { get; set; default = Actions.State.ANY; }
        public Actions.Trigger triggers { get; set; default = Actions.Trigger.NONE; }
        public bool command_valid { get; private set; default = false; }

        private string _command;
        private GLib.Settings settings;
        private GLib.SimpleAction remove_action;

        public Action.for_path (string path)
        {
            this.path = path;
        }

        /**
         * Reset action to defaults
         */
        public void reset ()
        {
            this.settings.delay ();
            this.settings.reset ("name");
            this.settings.reset ("command");
            this.settings.reset ("states");
            this.settings.reset ("triggers");
            this.settings.apply ();
        }

        public GLib.ActionGroup get_action_group ()
        {
            var action_group = new GLib.SimpleActionGroup ();

            this.remove_action = new GLib.SimpleAction ("remove", null);
            this.remove_action.activate.connect (this.activate_remove);
            action_group.add_action (this.remove_action);

            return action_group;
        }

        private void activate_remove (GLib.SimpleAction action,
                                      GLib.Variant?     parameter)
        {
            var action_manager = Actions.ActionManager.get_instance ();

            action_manager.remove (this);
        }

        private void validate_command ()
        {
            string[] spawn_args;

            try {
                this.command_valid = GLib.Shell.parse_argv (this.command,
                                                            out spawn_args);
            }
            catch (GLib.ShellError error) {
                this.command_valid = false;
            }
        }

        public bool execute (Actions.Context context)
        {
            string[] spawn_env = GLib.Environ.get ();
            string[] spawn_args;
            string[] trigger_strings = {};

            foreach (var trigger in context.triggers.to_list ())
            {
                trigger_strings += trigger.to_string ();
            }

            var command = this.command;
            command = command.replace ("$(state)",
                                       context.state.to_string ());
            command = command.replace ("$(elapsed)",
                                       context.elapsed.to_string ());
            command = command.replace ("$(duration)",
                                       context.duration.to_string ());
            command = command.replace ("$(triggers)",
                                       string.joinv (" ", trigger_strings));

            try {
                GLib.Shell.parse_argv (command, out spawn_args);
            }
            catch (GLib.ShellError error) {
                GLib.debug ("Error while executing command \"%s\": %s", command, error.message);
                return false;
            }

            try {
                GLib.Process.spawn_sync ("/",
                                         spawn_args,
                                         spawn_env,
                                         GLib.SpawnFlags.SEARCH_PATH,
                                         null);
            }
            catch (GLib.SpawnError error) {
                stdout.printf ("Error: %s\n", error.message);
                return false;
            }

            return true;
        }
    }
}
