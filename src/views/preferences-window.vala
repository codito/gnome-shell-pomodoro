/*
 * Copyright (c) 2013,2014,2016,2024 gnome-pomodoro contributors
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
    private class PreferencesPanelInfo : GLib.Object
    {
        public string    name { get; set; }
        public string    title { get; set; }
        public string    icon_name { get; set; }
        public GLib.Type content_class { get; set; }
        public bool      visible { get; set; default = true; }
    }


    private Gtk.SingleSelection create_model ()
    {
        Pomodoro.PreferencesPanelInfo? panel_info;

        var model = new GLib.ListStore (typeof (Pomodoro.PreferencesPanelInfo));

        panel_info = new PreferencesPanelInfo ();
        panel_info.name = "timer";
        panel_info.title = _("Timer");
        panel_info.icon_name = "timer-symbolic";
        panel_info.content_class = typeof (Pomodoro.PreferencesPanelTimer);
        model.append (panel_info);

        panel_info = new PreferencesPanelInfo ();
        panel_info.name = "notifications";
        panel_info.title = _("Notifications");
        panel_info.icon_name = "preferences-notifications-symbolic";
        panel_info.content_class = typeof (Pomodoro.PreferencesPanelNotifications);
        model.append (panel_info);

        panel_info = new PreferencesPanelInfo ();
        panel_info.name = "sounds";
        panel_info.title = _("Sounds");
        panel_info.icon_name = "preferences-sounds-symbolic";
        panel_info.content_class = typeof (Pomodoro.PreferencesPanelSounds);
        model.append (panel_info);

        panel_info = new PreferencesPanelInfo ();
        panel_info.name = "appearance";
        panel_info.title = _("Appearance");
        panel_info.icon_name = "preferences-appearance-symbolic";
        panel_info.content_class = typeof (Pomodoro.PreferencesPanelAppearance);
        model.append (panel_info);

        panel_info = new PreferencesPanelInfo ();
        panel_info.name = "actions";
        panel_info.title = _("Custom Actions");
        panel_info.icon_name = "custom-action-symbolic";
        panel_info.content_class = typeof (Pomodoro.PreferencesPanelActions);
        model.append (panel_info);

        return new Gtk.SingleSelection ((owned) model);
    }


    public class PreferencesPanel : Adw.NavigationPage
    {
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-window.ui")]
    public class PreferencesWindow : Adw.ApplicationWindow, Gtk.Buildable
    {
        public Gtk.SingleSelection? model
        {
            get {
                return this._model;
            }
            construct {
                this._model = create_model ();
            }
        }

        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild]
        private unowned Adw.NavigationSplitView split_view;
        [GtkChild]
        private unowned Pomodoro.PreferencesSidebar sidebar;

        private Gtk.SingleSelection? _model = null;
        private GLib.Settings?       settings = null;

        construct
        {
            this.settings = Pomodoro.get_settings ();

            this.load_window_state ();

            this.model.selection_changed.connect (this.on_selection_changed);

            this.sidebar.model = model;

            this.split_view.notify["collapsed"].connect (this.on_split_view_collapsed_notify);

            this.update_split_view_content ();
        }

        private void load_window_state ()
        {
            var current_width = -1;
            var current_height = -1;
            var maximized = false;

            this.settings.@get ("preferences-window-state",
                                "(iib)",
                                out current_width,
                                out current_height,
                                out maximized);

            if (current_width != -1 && current_height != -1) {
                this.set_default_size (current_width, current_height);
            }

            if (maximized) {
                this.maximize ();
            }
        }

        private void save_window_state ()
        {
            var current_width = -1;
            var current_height = -1;
            var maximized = this.is_maximized ();

            this.get_default_size (out current_width, out current_height);

            this.settings.@set ("preferences-window-state",
                                "(iib)",
                                current_width,
                                current_height,
                                maximized);
        }

        private void update_split_view_content ()
        {
            var panel_info = (Pomodoro.PreferencesPanelInfo?) this.model.selected_item;

            if (panel_info != null)
            {
                var content = (Pomodoro.PreferencesPanel) GLib.Object.@new (panel_info.content_class);
                content.title = panel_info.title;

                this.split_view.content = content;
                this.split_view.show_content = true;
            }
            else {
                this.split_view.show_content = false;
            }
        }

        private void on_split_view_collapsed_notify ()
        {
            this.sidebar.selection_mode = this.split_view.collapsed ? Gtk.SelectionMode.NONE : Gtk.SelectionMode.SINGLE;
        }

        private void on_selection_changed (uint position,
                                           uint n_items)
        {
            this.update_split_view_content ();
        }

        public void add_toast (owned Adw.Toast toast)
        {
            this.toast_overlay.add_toast (toast);
        }

        public override void unmap ()
        {
            this.save_window_state ();

            base.unmap ();
        }

        public override void dispose ()
        {
            if (this._model != null) {
                this._model.selection_changed.disconnect (this.on_selection_changed);
                this._model = null;
            }

            base.dispose ();
        }
    }
}
