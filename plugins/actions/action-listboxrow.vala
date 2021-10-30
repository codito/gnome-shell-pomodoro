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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/plugins/actions/action-listboxrow.ui")]
    public class ActionListBoxRow : Gtk.ListBoxRow
    {
        public Actions.Action action { get; private set; }
        public int position { get; set; default = -1; }

        [GtkChild]
        private unowned Gtk.Label name_label;
        [GtkChild]
        private unowned Gtk.FlowBox keywords_flowbox;
        [GtkChild]
        private unowned Gtk.MenuButton options_button;

        public ActionListBoxRow (Actions.Action action)
        {
            this.action = action;
            this.action.bind_property ("name",
                                       this.name_label,
                                       "label",
                                       GLib.BindingFlags.SYNC_CREATE);
            this.action.notify["states"].connect (this.on_action_states_notify);

            this.insert_action_group ("action", this.action.get_action_group ());

            try {
                var menu_builder = new Gtk.Builder ();
                menu_builder.add_from_resource ("/org/gnomepomodoro/Pomodoro/plugins/actions/menus.ui");

                var options_model = menu_builder.get_object ("action") as GLib.MenuModel;
                var options_popover = new Gtk.Popover.from_model (this.options_button,
                                                                  options_model);
                this.options_button.popover = options_popover;
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            this.on_action_states_notify ();
        }

        private void on_action_states_notify ()
        {
            // TODO: Don't update unless mapped

            this.keywords_flowbox.@foreach (
                (child) => {
                    child.destroy ();
                });

            foreach (var state in this.action.states.to_list ())
            {
                this.keywords_flowbox.add (
                        new Gtk.Label (state.get_label ()));
            }
        }
     }
}
