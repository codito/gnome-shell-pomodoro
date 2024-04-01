using GLib;


namespace Pomodoro
{
    /**
     * A list model for storing actions in settings.
     *
     * Each action is stored using an relocatable schema. There is no API to list relocatable
     * schemas or their subfolders, so we need to keep subfolders as `actions` key. `actions`
     * also stores the actions order.
     */
    public class ActionListModel : GLib.Object, GLib.ListModel
    {
        public uint n_items
        {
            get {
                return this._n_items;
            }
        }

        private GLib.HashTable<string, Pomodoro.Action> actions;
        private string[]                                uuids;
        private uint                                    _n_items = 0;
        private GLib.Settings                           settings = null;
        private ulong                                   settings_changed_id = 0;
        private int                                     settings_changed_inhibit_count = 0;

        construct
        {
            this.uuids = new string[0];
            this.actions = new GLib.HashTable<string, Pomodoro.Action> (GLib.str_hash,
                                                                        GLib.str_equal);

            this.settings = new GLib.Settings ("org.gnomepomodoro.Pomodoro.actions");
            this.settings_changed_id = this.settings.changed.connect (this.on_settings_changed);

            this.load ();
        }

        private void load_uuids ()
        {
            var uuids = this.settings.get_strv ("actions");
            var unique_uuids = new GLib.GenericSet<string> (GLib.str_hash, GLib.str_equal);

            this.uuids.resize (0);
            this._n_items = 0;

            foreach (var uuid in uuids)
            {
                if (!unique_uuids.contains (uuid))
                {
                    this.uuids += uuid;
                    this._n_items++;
                    unique_uuids.add (uuid);
                }
            }
        }

        private void save_uuids ()
        {
            this.settings.set_strv ("actions", this.uuids);
        }

        private GLib.Settings create_action_settings (string uuid)
                                                      requires (uuid != null && uuid != "")
        {
            var existing_settings = this.actions.lookup (uuid)?.settings;

            if (existing_settings != null) {
                return existing_settings;
            }

            return new GLib.Settings.with_path ("org.gnomepomodoro.Pomodoro.actions.action",
                                                @"/org/gnomepomodoro/Pomodoro/actions/$(uuid)/");
        }

        private void inhibit_settings_changed ()
        {
            this.settings_changed_inhibit_count++;
        }

        private void uninhibit_settings_changed ()
        {
            this.settings_changed_inhibit_count--;
        }

        private Pomodoro.Action load_action (string uuid)
        {
            var settings = this.create_action_settings (uuid);
            var action = this.create_action (uuid, settings.get_enum ("trigger"));

            action.load (settings);

            this.actions.insert (uuid, action);

            settings.changed.connect (
                (key) => {
                    if (this.settings_changed_inhibit_count > 0) {
                        return;
                    }

                    if (key == "trigger") {
                        this.reload_action (uuid);
                    }
                });

            return action;
        }

        private void reload_action (string uuid)
        {
            var action = this.load_action (uuid);
            var position = this.index (action.uuid);

            if (position >= 0) {
                this.items_changed ((uint) position, 1U, 1U);
            }
        }

        private void load ()
        {
            var previous_n_items = this._n_items;

            this.load_uuids ();

            foreach (var uuid in this.uuids) {
                this.load_action (uuid);
            }

            this.items_changed (0, this._n_items, previous_n_items);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            if (this.settings_changed_inhibit_count > 0) {
                return;
            }

            switch (key)
            {
                case "actions":
                    // TODO: detect which actions were removed and update `this.uuids`
                    break;
            }
        }

        public GLib.Type get_item_type ()
        {
            return typeof (Pomodoro.Action);
        }

        public uint get_n_items ()
        {
            return this._n_items;
        }

        public GLib.Object? get_item (uint position)
        {
            if (position >= this._n_items) {
                return null;
            }

            var uuid = this.uuids[position];
            var action = this.actions.lookup (uuid);

            if (action == null) {
                action = this.load_action (uuid);
            }

            return (GLib.Object?) action;
        }

        public int index (string uuid)
        {
            for (var position = 0; position < this._n_items; position++)
            {
                if (this.uuids[position] == uuid) {
                    return position;
                }
            }

            return -1;
        }

        public Pomodoro.Action? lookup (string uuid)
        {
            return this.actions.lookup (uuid);
        }

        /**
         * Initialize an action instance.
         */
        public Pomodoro.Action create_action (string?                uuid = null,
                                              Pomodoro.ActionTrigger trigger = Pomodoro.ActionTrigger.EVENT)
        {
            switch (trigger)
            {
                case Pomodoro.ActionTrigger.EVENT:
                    return new Pomodoro.EventAction (uuid);

                case Pomodoro.ActionTrigger.CONDITION:
                    return new Pomodoro.ConditionAction (uuid);

                default:
                    assert_not_reached ();
            }
        }

        public void save_action (Pomodoro.Action action)
        {
            var creating = action.uuid == null;
            var settings = action.settings;
            var position = 0U;
            Pomodoro.Action? previous_action = null;

            if (creating) {
                action.set_uuid_internal (GLib.Uuid.string_random ());
                position = this._n_items;
            }
            else {
                var index = this.index (action.uuid);

                if (index >= 0) {
                    position = (uint) index;
                    previous_action = this.actions.lookup (action.uuid);
                }
                else {
                    creating = true;
                    position = this._n_items;
                }
            }

            if (settings == null) {
                settings = this.create_action_settings (action.uuid);
            }

            this.actions.insert (action.uuid, action);

            this.inhibit_settings_changed ();
            action.save (settings);
            this.uninhibit_settings_changed ();

            if (creating)
            {
                this.uuids += action.uuid;
                this._n_items++;
                this.save_uuids ();

                this.action_added (action);
                this.items_changed (position, 0U, 1U);
            }
            else {
                this.action_replaced (action, previous_action);

                this.items_changed (position, 1U, 1U);
            }
        }

        public void delete_action (string uuid)
        {
            var action = this.actions.lookup (uuid);

            if (action == null) {
                return;
            }

            var new_uuids = new string[0];
            var changed = false;
            var position = 0U;
            var settings = action.settings;

            foreach (var _uuid in this.uuids)
            {
                if (_uuid != uuid)
                {
                    new_uuids += _uuid;

                    if (!changed) {
                        position++;
                    }
                }
                else {
                    changed = true;
                }
            }

            if (settings != null)
            {
                this.inhibit_settings_changed ();

                foreach (var key in settings.settings_schema.list_keys ()) {
                    settings.reset (key);
                }

                this.uninhibit_settings_changed ();
            }

            this.actions.remove (uuid);

            if (changed)
            {
                this.uuids = new_uuids;
                this._n_items = new_uuids.length;
                this.save_uuids ();

                this.action_removed (action);
                this.items_changed (position, 1U, 0U);
            }
        }

        public void move_action (string uuid,
                                 uint   position)
        {
            var source_position = this.index (uuid);
            var destination_position = int.min ((int) position, this.uuids.length - 1);
            var n_changes = (source_position - destination_position).abs ();
            var direction = destination_position > source_position
                ? 1    // move source id to the right
                : -1;  // move source id to the left

            if (source_position < 0 || destination_position < 0 || n_changes == 0) {
                return;
            }

            for (var i = 0; i < n_changes; i++) {
                this.uuids[source_position + i * direction] = this.uuids[source_position + (i + 1) * direction];
            }

            this.uuids[destination_position] = uuid;

            this.save_uuids ();

            this.items_changed (uint.min (source_position, destination_position), n_changes, n_changes);
        }

        public signal void action_added (Pomodoro.Action action);

        public signal void action_removed (Pomodoro.Action action);

        public signal void action_replaced (Pomodoro.Action action,
                                            Pomodoro.Action previous_action);

        public override void dispose ()
        {
            if (this.settings_changed_id != 0) {
                this.settings.disconnect (this.settings_changed_id);
                this.settings_changed_id = 0;
            }

            this.uuids = null;
            this.settings = null;

            base.dispose ();
        }
    }
}
