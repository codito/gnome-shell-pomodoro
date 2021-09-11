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
    private const string ACTION_PATH_PREFIX = "/org/gnomepomodoro/Pomodoro/plugins/actions/action";
    private const string ACTION_PATH_SUFFIX = "/";


    public struct Context
    {
        public Actions.Action action;
        public Actions.Trigger triggers;
        public Actions.State state;
        public double elapsed;
        public double duration;
    }


    public class ActionManager : GLib.Object
    {
        private static unowned ActionManager instance;

        private GLib.List<Actions.Action> actions;
        private GLib.HashTable<string, unowned Actions.Action> actions_hash;
        private GLib.Settings settings;

        construct
        {
            Actions.ActionManager.instance = this;

            this.settings = new GLib.Settings ("org.gnomepomodoro.Pomodoro.plugins.actions");
            this.settings.changed.connect (this.on_settings_changed);

            this.actions_hash = new GLib.HashTable<string, unowned Actions.Action> (str_hash, str_equal);

            this.populate ();
        }

        public static Actions.ActionManager get_instance ()
        {
            return Actions.ActionManager.instance;
        }

        public GLib.List<unowned Actions.Action> get_actions ()
        {
            var actions = new GLib.List<unowned Actions.Action> ();

            foreach (var action in this.actions)
            {
                actions.append (action);
            }

            return actions;
        }

        /**
         * Load items from settings
         */
        private void populate ()
        {
            var new_actions = new GLib.List<Actions.Action> ();
            var new_paths_hash = new GLib.GenericSet<string> (str_hash, str_equal);

            foreach (var path in this.settings.get_strv ("actions-list"))
            {
                var action = this.actions_hash.lookup (path);

                if (action == null) {
                    action = new Actions.Action.for_path (path);

                    this.actions_hash.insert (action.path, action);
                }

                new_actions.append (action);
                new_paths_hash.add (action.path);
            }

            foreach (var action in this.actions)
            {
                if (!new_paths_hash.contains (action.path)) {
                    this.remove_internal (action);
                }
            }

            this.actions = (owned) new_actions;

            this.actions_changed ();
        }

        /**
         * Extract action ID from path
         */
        private static int extract_id (string path)
        {
            if (path.has_prefix (ACTION_PATH_PREFIX) &&
                path.has_suffix (ACTION_PATH_SUFFIX))
            {
                var path_part = path.slice (ACTION_PATH_PREFIX.length,
                                path.length - ACTION_PATH_SUFFIX.length);

                return int.parse (path_part);
            }

            return -1;
        }

        private uint get_next_id ()
        {
            var next_id = 0;
            unowned GLib.List<Actions.Action> iter = this.actions.first ();

            while (iter != null)
            {
                var action = iter.data;

                if (extract_id (action.path) == next_id) {
                    next_id++;
                    iter = this.actions.first ();
                }
                else {
                    iter = iter.next;
                }
            }

            return (uint) next_id;
        }

        private void add_internal (Actions.Action action,
                                   int            position = -1)
        {
            this.actions_hash.insert (action.path, action);
            this.actions.insert (action, position);
        }

        private void remove_internal (Actions.Action action)
        {
            this.actions_hash.remove (action.path);
            this.actions.remove (action);

            action.reset ();
        }

        public void add (Actions.Action action,
                         int            position = -1)
        {
            if (action.path == null) {
                action.path = "/org/gnomepomodoro/Pomodoro/plugins/actions/action%u/".printf (this.get_next_id ());
            }

            this.add_internal (action, position);

            this.actions_changed ();
        }

        public void remove (Actions.Action action)
        {
            this.remove_internal (action);

            this.actions_changed ();
        }

        // TODO: methods to change order on a list

        private void on_settings_changed (string key)
        {
            switch (key)
            {
                case "actions-list":
                    this.populate ();
                    break;
            }
        }

        /**
         * Save actions to settings
         */
        [Signal (no_recurse = "true")]
        public virtual signal void actions_changed ()
        {
            string[] paths = this.settings.get_strv ("actions-list");
            string[] new_paths = {};
            var has_changed = false;

            foreach (var action in this.actions) {
                new_paths += action.path;
            }

            for (var i = 0; ; i++) {
                if (paths[i] != new_paths[i]) {
                    has_changed = true;
                    break;
                }

                if (paths[i] == null) {
                    break;
                }
            }

            if (has_changed) {
                this.settings.set_strv ("actions-list", new_paths);
            }
        }

        public override void dispose ()
        {
            Actions.ActionManager.instance = null;

            base.dispose ();
        }
    }


    private class ApplicationExtensionInternals : GLib.Object
    {
        private GLib.AsyncQueue<Actions.Context?> jobs_queue;
        private GLib.Thread<bool> jobs_thread;
        private Actions.ActionManager actions_manager;
        private Pomodoro.Timer timer;

        construct
        {
            this.actions_manager = new Actions.ActionManager ();

            this.jobs_queue = new GLib.AsyncQueue<Actions.Context?> ();
            this.jobs_thread = new GLib.Thread<bool> ("actions-queue", this.jobs_thread_func);

            this.timer = Pomodoro.Timer.get_default ();
            this.timer.state_changed.connect (this.on_timer_state_changed);
            this.timer.notify["is-paused"].connect (this.on_timer_is_paused_notify);

            if (!(this.timer.state is Pomodoro.DisabledState)) {
                this.on_timer_state_changed (this.timer.state, new Pomodoro.DisabledState ());
            }
            else {
                this.on_timer_state_changed (this.timer.state, this.timer.state);
            }

            if (this.timer.is_paused) {
               this.on_timer_is_paused_notify ();
            }

            this.@ref ();
        }

        private bool jobs_thread_func ()
        {
            while (true) {
                var context = this.jobs_queue.pop ();

                if (context.triggers != Actions.Trigger.NONE) {
                    context.action.execute (context);
                }
                else {
                    break;
                }
            }

            this.@unref ();

            return true;
        }

        private void on_timer_is_paused_notify ()
        {
            var timer    = this.timer;
            var actions  = Actions.ActionManager.get_instance ().get_actions ();
            var states   = Actions.State.from_timer_state (timer.state);
            var triggers = timer.is_paused ? Actions.Trigger.PAUSE : Actions.Trigger.RESUME;

            foreach (var action in actions)
            {
                var states_match = action.states & states;
                var triggers_match = action.triggers & triggers;

                if (states_match != 0 && triggers_match != 0)
                {
                    this.jobs_queue.push (Actions.Context () {
                        action = action,
                        triggers = triggers_match,
                        state = states_match,
                        elapsed = timer.state.elapsed,
                        duration = timer.state.duration
                    });
                }
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            var actions    = Actions.ActionManager.get_instance ().get_actions ();
            var states_a   = Actions.State.from_timer_state (previous_state);
            var states_b   = Actions.State.from_timer_state (state);
            var triggers_a = Actions.Trigger.NONE;
            var triggers_b = Actions.Trigger.NONE;

            if (previous_state is Pomodoro.DisabledState) {
                triggers_b |= Actions.Trigger.ENABLE;
            }

            if (state is Pomodoro.DisabledState) {
                triggers_a |= Actions.Trigger.DISABLE;
            }
            else {
                triggers_b |= Actions.Trigger.START;
            }

            if (previous_state.is_completed ()) {
                triggers_a |= Actions.Trigger.COMPLETE;
            }
            else {
                triggers_a |= Actions.Trigger.SKIP;
            }

            /* actions for previous state */
            foreach (var action in actions)
            {
                var states_match = action.states & states_a;
                var triggers_match = action.triggers & triggers_a;

                if (states_match != 0 && triggers_match != 0)
                {
                    this.jobs_queue.push (Actions.Context () {
                        action = action,
                        triggers = triggers_match,
                        state = states_match,
                        elapsed = previous_state.elapsed,
                        duration = previous_state.duration
                    });
                }
            }

            /* actions for current state */
            foreach (var action in actions)
            {
                var states_match = action.states & states_b;
                var triggers_match = action.triggers & triggers_b;

                if (states_match != 0 && triggers_match != 0)
                {
                    this.jobs_queue.push (Actions.Context () {
                        action = action,
                        triggers = triggers_match,
                        state = states_match,
                        elapsed = state.elapsed,
                        duration = state.duration
                    });
                }
            }
        }

        public override void dispose ()
        {
            this.on_timer_state_changed (new Pomodoro.DisabledState (), this.timer.state);

            this.jobs_queue.push (Actions.Context () {
                triggers = Actions.Trigger.NONE
            });

            base.dispose ();
        }
    }


    public class ApplicationExtension : Peas.ExtensionBase, Pomodoro.ApplicationExtension
    {
        private Gtk.CssProvider css_provider;
        private Actions.ApplicationExtensionInternals internals;

        construct
        {
            this.css_provider = new Gtk.CssProvider ();
            this.css_provider.load_from_resource ("/org/gnomepomodoro/Pomodoro/plugins/actions/style.css");

            Gtk.StyleContext.add_provider_for_screen (
                                         Gdk.Screen.get_default (),
                                         this.css_provider,
                                         Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            this.internals = new Actions.ApplicationExtensionInternals ();
        }

        public override void dispose ()
        {
            Gtk.StyleContext.remove_provider_for_screen (Gdk.Screen.get_default (), this.css_provider);

            this.internals.dispose ();

            base.dispose ();
        }
    }


    public class PreferencesDialogExtension : Peas.ExtensionBase, Pomodoro.PreferencesDialogExtension
    {
        private Pomodoro.PreferencesDialog dialog;
        private GLib.List<Gtk.ListBoxRow> rows;

        construct
        {
            this.dialog = Pomodoro.PreferencesDialog.get_default ();

            this.dialog.add_page ("actions",
                                  _("Actions"),
                                  typeof (Actions.PreferencesPage));

            this.dialog.add_page ("add-action",
                                  _("Action"),
                                  typeof (Actions.ActionPage));

            this.setup_main_page ();
        }

        ~PreferencesDialogExtension ()
        {
            if (this.dialog != null) {
                this.dialog.remove_page ("actions");
                this.dialog.remove_page ("add-action");
            }

            foreach (var row in this.rows) {
                row.destroy ();
            }

            this.rows = null;
        }

        private void setup_main_page ()
        {
            var main_page = this.dialog.get_page ("main") as Pomodoro.PreferencesMainPage;
            main_page.plugins_listbox.row_activated.connect (this.on_row_activated);

            var row = this.create_row (_("Custom actions…"), "actions");
            main_page.lisboxrow_sizegroup.add_widget (row);

            main_page.plugins_listbox.insert (row, 0);

            this.rows.prepend (row);
        }

        private Gtk.ListBoxRow create_row (string label,
                                           string name)
        {
            var name_label = new Gtk.Label (label);
            name_label.halign = Gtk.Align.START;
            name_label.valign = Gtk.Align.BASELINE;

            var row = new Gtk.ListBoxRow ();
            row.name = name;
            row.selectable = false;
            row.add (name_label);
            row.show_all ();

            return row;
        }

        private void on_row_activated (Gtk.ListBox    listbox,
                                       Gtk.ListBoxRow row)
        {
            if (row.name == "actions") {
                this.dialog.set_page ("actions");
            }
        }
    }
}


[ModuleInit]
public void peas_register_types (GLib.TypeModule module)
{
    var object_module = module as Peas.ObjectModule;

    object_module.register_extension_type (typeof (Pomodoro.ApplicationExtension),
                                           typeof (Actions.ApplicationExtension));

    object_module.register_extension_type (typeof (Pomodoro.PreferencesDialogExtension),
                                           typeof (Actions.PreferencesDialogExtension));
}
