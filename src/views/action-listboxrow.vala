/*
 * Copyright (c) 2016, 2024 gnome-pomodoro contributors
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


namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/action-listboxrow.ui")]
    public class ActionListBoxRow : Gtk.ListBoxRow
    {
        public Pomodoro.Action action {
            get {
                return this._action;
            }
            set {
                if (this._action == value) {
                    return;
                }

                if (this.enabled_switch_binding != null) {
                    this.enabled_switch_binding.unbind ();
                    this.enabled_switch_binding = null;
                }

                this._action = value;
                this.enabled_switch_binding = this._action.bind_property (
                        "enabled",
                        this.enabled_switch,
                        "active",
                        GLib.BindingFlags.SYNC_CREATE | GLib.BindingFlags.BIDIRECTIONAL);

                this.update_display_name ();
            }
        }
        public uint sort_order { get; set; default = 0U; }

        [GtkChild]
        private unowned Gtk.Label display_name_label;
        [GtkChild]
        private unowned Gtk.Switch enabled_switch;

        private Pomodoro.Action?      _action = null;
        private unowned GLib.Binding? enabled_switch_binding = null;
        private double                drag_x;
        private double                drag_y;
        private Gtk.ListBox?          drag_widget = null;

        public ActionListBoxRow (Pomodoro.Action action)
        {
            GLib.Object (
                action: action
            );
        }

        /**
         * Assume that action-list will set a new `action` here after it gets saved.
         */
        private void update_display_name ()
        {
            if (this._action != null) {
                this.display_name_label.label = this._action.display_name != ""
                        ? this._action.display_name
                        : _("Untitled action");
            }
        }

        [GtkCallback]
        private Gdk.ContentProvider? on_drag_prepare (double x,
                                                      double y)
        {
            this.drag_x = x;
            this.drag_y = y;

            var drag_value = GLib.Value (typeof (Pomodoro.ActionListBoxRow));
            drag_value.set_object (this);

            return new Gdk.ContentProvider.for_value (drag_value);
        }

        [GtkCallback]
        private void on_drag_begin (Gdk.Drag drag)
        {
            var row = new Pomodoro.ActionListBoxRow (this._action);

            this.drag_widget = new Gtk.ListBox ();
            this.drag_widget.set_size_request (this.get_width (), this.get_height ());
            this.drag_widget.append (row);
            this.drag_widget.drag_highlight_row (row);

            var drag_icon = (Gtk.DragIcon) Gtk.DragIcon.get_for_drag (drag);
            drag_icon.child = this.drag_widget;

            drag.set_hotspot ((int) this.drag_x, (int) this.drag_y);
        }

        [GtkCallback]
        private bool on_drop (GLib.Value value,
                              double     x,
                              double     y)
        {
            if (!value.holds (typeof (Pomodoro.ActionListBoxRow))) {
                return false;
            }

            var source = (Pomodoro.ActionListBoxRow) value.get_object ();

            source.move_row (this);

            return true;
        }

        [HasEmitter]
        public signal void move_row (Pomodoro.ActionListBoxRow destination_row);

        public override void dispose ()
        {
            if (this.enabled_switch_binding != null) {
                this.enabled_switch_binding.unbind ();
                this.enabled_switch_binding = null;
            }

            this._action = null;
            this.drag_widget = null;

            base.dispose ();
        }
     }
}
