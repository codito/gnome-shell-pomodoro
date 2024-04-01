namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-panel-actions.ui")]
    public class PreferencesPanelActions : Pomodoro.PreferencesPanel
    {
        [GtkChild]
        private unowned Adw.PreferencesRow add_row;

        private Pomodoro.ActionManager?                                    action_manager = null;
        private GLib.HashTable<string, unowned Pomodoro.ActionListBoxRow>? rows = null;
        private unowned Gtk.ListBox                                        listbox = null;
        private uint                                                       update_idle_id = 0;

        construct
        {
            this.rows = new GLib.HashTable<string, unowned Pomodoro.ActionListBoxRow> (
                    GLib.str_hash, GLib.str_equal);

            this.action_manager = new Pomodoro.ActionManager ();
            this.action_manager.model.items_changed.connect (this.on_items_changed);

            this.listbox = (Gtk.ListBox) this.add_row.parent;
            this.listbox.selection_mode = Gtk.SelectionMode.NONE;
            this.listbox.set_sort_func (sort_func);
            this.listbox.row_activated.connect (this.on_listbox_row_activated);

            this.update ();
        }

        private static int sort_func (Gtk.ListBoxRow row_1,
                                      Gtk.ListBoxRow row_2)
        {
            var action_row_1 = row_1 as Pomodoro.ActionListBoxRow;
            var action_row_2 = row_2 as Pomodoro.ActionListBoxRow;

            if (action_row_1 == null) {
                return 1;
            }

            if (action_row_2 == null) {
                return -1;
            }

            return (int) action_row_1.sort_order - (int) action_row_2.sort_order;
        }

        private void update ()
        {
            var model = this.action_manager.model;
            var n_items = model.n_items;
            var to_remove = new GLib.GenericSet<unowned Pomodoro.ActionListBoxRow> (GLib.direct_hash, GLib.direct_equal);

            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            this.rows.@foreach (
                (uuid, row) => {
                    to_remove.add (row);
                });

            for (var position = 0U; position < n_items; position++)
            {
                var action = (Pomodoro.Action?) model.get_item (position);
                assert (action != null);

                var row = this.rows.lookup (action.uuid);

                if (row != null) {
                    row.action = action;
                }
                else {
                    row = new Pomodoro.ActionListBoxRow (action);
                    row.move_row.connect (this.on_move_row);

                    this.listbox.append (row);
                    this.rows.insert (action.uuid, row);
                }

                row.sort_order = position;
                to_remove.remove (row);
            }

            to_remove.@foreach (
                (row) => {
                    row.move_row.disconnect (this.on_move_row);

                    this.rows.remove (row.action.uuid);
                    this.listbox.remove (row);
                });

            this.listbox.invalidate_sort ();

            // TODO disconnect signals of removed actions?
        }

        private void open_action_edit_window (Pomodoro.Action action)
        {
            var window = new Pomodoro.ActionEditWindow (action.uuid);
            window.set_transient_for ((Gtk.Window?) this.get_root ());
            window.present ();
        }

        private void on_items_changed (uint position,
                                       uint removed,
                                       uint added)
        {
            if (this.update_idle_id == 0)
            {
                this.update_idle_id = this.add_tick_callback (() => {
                    this.update_idle_id = 0;
                    this.update ();

                    return GLib.Source.REMOVE;
                });
            }
        }

        private void on_listbox_row_activated (Gtk.ListBoxRow row)
        {
            if (row == this.add_row) {
                this.open_action_edit_window (new Pomodoro.EventAction ());
            }
            else {
                this.open_action_edit_window (((Pomodoro.ActionListBoxRow) row).action);
            }
        }

        private void on_move_row (Pomodoro.ActionListBoxRow row,
                                  Pomodoro.ActionListBoxRow destination_row)
        {
            this.action_manager.model.move_action (row.action.uuid, destination_row.sort_order);

            this.update ();
        }

        public override void dispose ()
        {
            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            if (this.action_manager != null) {
                this.action_manager.model.items_changed.disconnect (this.on_items_changed);
            }

            if (this.listbox != null) {
                this.listbox.row_activated.disconnect (this.on_listbox_row_activated);
            }

            if (this.rows != null) {
                this.rows.remove_all ();
                this.rows = null;
            }

            this.rows = null;
            this.listbox = null;
            this.action_manager = null;

            base.dispose ();
        }
    }
}
