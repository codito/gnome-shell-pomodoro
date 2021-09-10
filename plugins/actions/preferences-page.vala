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
    private void list_box_separator_func (Gtk.ListBoxRow  row,
                                          Gtk.ListBoxRow? before)
    {
        if (before != null) {
            var header = row.get_header ();

            if (header == null) {
                header = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                header.show ();
                row.set_header (header);
            }
        }
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/plugins/actions/preferences-page.ui")]
    public class PreferencesPage : Gtk.Box, Pomodoro.PreferencesPage
    {
        [GtkChild]
        private unowned Gtk.ListBox actions_listbox;

        private Actions.ActionManager actions_manager;
        private GLib.HashTable<string, unowned Actions.ActionListBoxRow> rows_hash;

        construct
        {
            this.actions_listbox.set_header_func (Actions.list_box_separator_func);
            this.actions_listbox.set_sort_func (PreferencesPage.actions_listbox_sort_func);

            this.rows_hash = new GLib.HashTable<string, unowned Actions.ActionListBoxRow> (str_hash, str_equal);

            this.actions_manager = Actions.ActionManager.get_instance ();
            this.actions_manager.actions_changed.connect (this.on_actions_changed);

            this.populate ();
        }

        private static int actions_listbox_sort_func (Gtk.ListBoxRow row1,
                                                      Gtk.ListBoxRow row2)
        {
            if (row1.name == "add") {
                return 1;
            }

            if (row2.name == "add") {
                return -1;
            }

            var tmp1 = row1 as Actions.ActionListBoxRow;
            var tmp2 = row2 as Actions.ActionListBoxRow;

            if (tmp1.position < tmp2.position) {
                return -1;
            }

            if (tmp1.position > tmp2.position) {
                return 1;
            }

            return 0;
        }

        private void populate ()
        {
            var index = 0;
            var keep_paths_hash = new GLib.GenericSet<string> (str_hash, str_equal);

            foreach (var action in this.actions_manager.get_actions ())
            {
                var row = this.rows_hash.lookup (action.path);

                if (row == null) {
                    row = new Actions.ActionListBoxRow (action);
                    row.position = index;
                    row.show ();

                    this.rows_hash.insert (action.path, row);
                    this.actions_listbox.prepend (row);
                }
                else {
                    row.position = index;
                }

                keep_paths_hash.add (action.path);

                index++;
            }

            this.rows_hash.foreach_remove ((path, row) => {
                if (!keep_paths_hash.contains (path)) {
                    row.destroy ();
                    return true;
                }

                return false;
            });

            this.actions_listbox.invalidate_sort ();
        }

        private void on_actions_changed ()
        {
            this.populate ();
        }

        [GtkCallback]
        private void on_row_activated (Gtk.ListBox    listbox,
                                       Gtk.ListBoxRow row)
        {
            var preferences_dialog = this.get_preferences_dialog ();
            var page = preferences_dialog.get_page ("add-action") as Actions.ActionPage;

            if (row.name == "add") {
                var action = new Actions.Action ();
                this.actions_manager.add (action);

                page.set_action (action);
            }
            else {
                var tmp = row as Actions.ActionListBoxRow;

                page.set_action (tmp.action);
            }

            preferences_dialog.set_page ("add-action");
        }
    }
}
