/*
 * Copyright (c) 2013,2014,2016 gnome-pomodoro contributors
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
    /**
     * Mapping from settings to accelerator
     */
    private bool get_accelerator_mapping (GLib.Value   value,
                                          GLib.Variant variant,
                                          void*        user_data)
    {
        var accelerators = variant.get_strv ();

        foreach (var accelerator in accelerators)
        {
            value.set_string (accelerator);

            return true;
        }

        value.set_string ("");

        return true;
    }

    /**
     * Mapping from accelerator to settings
     */
    [CCode (has_target = false)]
    private GLib.Variant set_accelerator_mapping (GLib.Value       value,
                                                  GLib.VariantType expected_type,
                                                  void*            user_data)
    {
        var accelerator_name = value.get_string ();

        if (accelerator_name == "")
        {
            string[] strv = {};

            return new GLib.Variant.strv (strv);
        }
        else {
            string[] strv = { accelerator_name };

            return new GLib.Variant.strv (strv);
        }
    }

    private void list_box_separator_func (Gtk.ListBoxRow  row,
                                          Gtk.ListBoxRow? before)
    {
        if (before != null) {
            var header = row.get_header ();

            if (header == null) {
                header = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
                row.set_header (header);
            }
        }
    }

    public interface PreferencesWindowExtension : Peas.ExtensionBase
    {
    }

    public interface PreferencesPage : Gtk.Widget
    {
        public unowned Pomodoro.PreferencesWindow get_preferences_dialog ()
        {
            return this.root as Pomodoro.PreferencesWindow;
        }

        public virtual void configure_header_bar (Gtk.HeaderBar header_bar)
        {
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-keyboard-shortcut-page.ui")]
    public class PreferencesKeyboardShortcutPage : Gtk.Box, Gtk.Buildable, Pomodoro.PreferencesPage
    {
        private Pomodoro.Accelerator accelerator { get; set; }

        [GtkChild]
        private unowned Gtk.Box preview_box;
        [GtkChild]
        private unowned Gtk.Button disable_button;
        [GtkChild]
        private unowned Gtk.Label error_label;

        private GLib.Settings settings;
        // private ulong key_press_event_id = 0;
        // private ulong key_release_event_id = 0;
        // private ulong focus_out_event_id = 0;

        construct
        {
            this.accelerator = new Pomodoro.Accelerator ();
            this.accelerator.changed.connect (this.on_accelerator_changed);

            this.settings = Pomodoro.get_settings ()
                                    .get_child ("preferences");
            this.settings.delay ();

            this.settings.bind_with_mapping ("toggle-timer-key",
                                             this.accelerator,
                                             "name",
                                             GLib.SettingsBindFlags.DEFAULT,
                                             (GLib.SettingsBindGetMappingShared) get_accelerator_mapping,
                                             (GLib.SettingsBindSetMappingShared) set_accelerator_mapping,
                                             null,
                                             null);
            this.on_accelerator_changed ();
        }

        private bool validate_accelerator ()
        {
            var is_valid = false;

            try {
                this.accelerator.validate ();

                this.error_label.hide ();

                is_valid = true;
            }
            catch (Pomodoro.AcceleratorError error)
            {
                if (error is Pomodoro.AcceleratorError.TYPING_COLLISION)
                {
                    this.error_label.label = _(
                        "Using \"%s\" as shortcut will interfere with typing. Try adding another key, such as Control, Alt or Shift."  // vala-lint=line-length
                    ).printf (this.accelerator.display_name);
                    this.error_label.show ();
                }
            }

            return is_valid;
        }

        private void update_preview ()
        {
            var index = 0;

            var child = this.preview_box.get_first_child ();
            while (child != null) {
                var next_child = child.get_next_sibling ();
                child.destroy ();
                child = next_child;
            }

            foreach (var element in this.accelerator.get_keys ())
            {
                if (index > 0) {
                    this.preview_box.append (new Gtk.Label ("+"));
                }

                var key_label = new Gtk.Label (element);
                key_label.valign = Gtk.Align.CENTER;
                key_label.get_style_context ().add_class ("key");
                this.preview_box.append (key_label);

                index++;
            }

            this.disable_button.sensitive = index > 0;
        }

        [GtkCallback]
        private void on_disable_clicked ()
        {
            this.accelerator.unset ();

            this.settings.apply ();
        }

        private void on_accelerator_changed ()
        {
            this.validate_accelerator ();
            this.update_preview ();
        }

        // TODO: port to gtk4
        // private bool on_key_press_event (Gdk.EventKey event)
        // {
        //     switch (event.keyval)
        //     {
        //         case Gdk.Key.Tab:
        //         case Gdk.Key.space:
        //         case Gdk.Key.Return:
        //             return base.key_press_event (event);
        //
        //         case Gdk.Key.BackSpace:
        //             if (!this.settings.has_unapplied) {
        //                 this.on_disable_clicked ();
        //             }
        //
        //             return true;
        //
        //         case Gdk.Key.Escape:
        //             this.get_action_group ("win").activate_action ("back", null);
        //
        //             return true;
        //     }
        //
        //     this.accelerator.set_keyval (event.keyval,
        //                                  event.state);
        //
        //     return true;
        // }

        // private bool on_key_release_event (Gdk.EventKey event)
        // {
        //     switch (event.keyval)
        //     {
        //         case Gdk.Key.Tab:
        //         case Gdk.Key.space:
        //         case Gdk.Key.Return:
        //         case Gdk.Key.BackSpace:
        //             return true;
        //     }
        //
        //     if (event.state == 0 || event.length == 0)
        //     {
        //         try {
        //             this.accelerator.validate ();
        //
        //             this.settings.apply ();
        //         }
        //         catch (Pomodoro.AcceleratorError error)
        //         {
        //             this.settings.revert ();
        //         }
        //     }
        //
        //     return true;
        // }

        // private bool on_focus_out_event (Gdk.EventFocus event)
        // {
        //     if (!this.visible) {
        //         return false;
        //     }
        //
        //     this.settings.revert ();
        //
        //     return true;
        // }

        public override void map ()
        {
            base.map ();

            // var root = (Gtk.Widget) this.root;

            // if (this.key_press_event_id == 0) {
            //     this.key_press_event_id = root.key_press_event.connect (this.on_key_press_event);
            // }

            // if (this.key_release_event_id == 0) {
            //     this.key_release_event_id = root.key_release_event.connect (this.on_key_release_event);
            // }

            // if (this.focus_out_event_id == 0) {
            //     this.focus_out_event_id = root.focus_out_event.connect (this.on_focus_out_event);
            // }

            var application = Pomodoro.Application.get_default ();
            application.capability_manager.disable ("accelerator");
        }

        public override void unmap ()
        {
            base.unmap ();

            // var root = (Gtk.Widget) this.root;

            // if (this.key_press_event_id != 0) {
            //     root.key_press_event.disconnect (this.on_key_press_event);
            //     this.key_press_event_id = 0;
            // }

            // if (this.key_release_event_id != 0) {
            //     root.key_release_event.disconnect (this.on_key_release_event);
            //     this.key_release_event_id = 0;
            // }

            // if (this.focus_out_event_id != 0) {
            //     root.focus_out_event.disconnect (this.on_focus_out_event);
            //     this.focus_out_event_id != 0;
            // }

            var application = Pomodoro.Application.get_default ();
            application.capability_manager.enable ("accelerator");
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-plugins-page.ui")]
    public class PreferencesPluginsPage : Gtk.Box, Pomodoro.PreferencesPage
    {
        [GtkChild]
        private unowned Gtk.ListBox plugins_listbox;

        private GLib.Settings settings;
        private Peas.Engine engine;
        private GLib.HashTable<string, unowned Gtk.Switch> toggles;

        construct
        {
            this.settings = Pomodoro.get_settings ()
                                    .get_child ("preferences");
            this.settings.changed["enabled-plugins"].connect (this.on_settings_changed);

            this.engine = Peas.Engine.get_default ();

            this.plugins_listbox.set_header_func (Pomodoro.list_box_separator_func);
            this.plugins_listbox.set_sort_func (list_box_sort_func);

            this.toggles = new GLib.HashTable<string, unowned Gtk.Switch> (str_hash, str_equal);

            this.populate ();
        }

        private static int list_box_sort_func (Gtk.ListBoxRow row1,
                                               Gtk.ListBoxRow row2)
        {
            var name1 = row1.get_data<string> ("name");
            var name2 = row2.get_data<string> ("name");

            return GLib.strcmp (name1, name2);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            foreach (var plugin_info in this.engine.get_plugin_list ())
            {
                var toggle  = this.toggles.lookup (plugin_info.get_module_name ());
                var enabled = false;

                if (toggle != null) {
                    enabled = this.get_plugin_enabled (plugin_info.get_module_name ());

                    if (toggle.state != enabled) {
                        toggle.state = enabled;
                    }
                }
            }
        }

        private bool get_plugin_enabled (string name)
        {
            var enabled_plugins = this.settings.get_strv ("enabled-plugins");
            var enabled_in_settings = false;

            foreach (var plugin_name in enabled_plugins) {
                if (plugin_name == name) {
                    enabled_in_settings = true;

                    break;
                }
            }

            return enabled_in_settings;
        }

        private void set_plugin_enabled (string name,
                                         bool   value)
        {
            var enabled_plugins = this.settings.get_strv ("enabled-plugins");
            var enabled_in_settings = false;

            string[] tmp = {};

            foreach (var plugin_name in enabled_plugins) {
                if (plugin_name == name) {
                    enabled_in_settings = true;
                }
                else {
                    tmp += plugin_name;
                }
            }

            if (value) {
                tmp += name;
            }

            if (enabled_in_settings != value) {
                this.settings.set_strv ("enabled-plugins", tmp);
            }
        }

        private Gtk.ListBoxRow create_row (Peas.PluginInfo plugin_info)
        {
            var name_label = new Gtk.Label (plugin_info.get_name ());
            name_label.get_style_context ().add_class ("pomodoro-plugin-name");
            name_label.halign = Gtk.Align.START;

            var description_label = new Gtk.Label (plugin_info.get_description ());
            description_label.get_style_context ().add_class ("dim-label");
            description_label.get_style_context ().add_class ("pomodoro-plugin-description");
            description_label.halign = Gtk.Align.START;

            var toggle = new Gtk.Switch ();
            toggle.valign = Gtk.Align.CENTER;
            toggle.state = plugin_info.is_loaded ();
            toggle.notify["active"].connect (() => {
                this.set_plugin_enabled (plugin_info.get_module_name (), toggle.active);
            });
            toggle.state_set.connect ((state) => {
                var success = (state == plugin_info.is_loaded ());

                return !success;
            });

            this.toggles.insert (plugin_info.get_module_name (), toggle);

            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.append (name_label);
            vbox.append (description_label);

            var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 30);
            hbox.append (vbox);
            hbox.append (toggle);

            var row = new Gtk.ListBoxRow ();
            row.set_data<string> ("name", plugin_info.get_name ());
            row.activatable = false;
            row.set_child (hbox);

            return row;
        }

        private bool is_legacy_plugin (string plugin_name)
        {
            return false;
        }

        private void populate ()
        {
            this.engine.rescan_plugins ();

            foreach (var plugin_info in this.engine.get_plugin_list ())
            {
                if (plugin_info.is_hidden ()) {
                    continue;
                }

                if (this.is_legacy_plugin (plugin_info.get_module_name ())) {
                    continue;
                }

                var row = this.create_row (plugin_info);

                this.plugins_listbox.insert (row, -1);
            }
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/preferences-window.ui")]
    public class PreferencesWindow : Adw.ApplicationWindow, Gtk.Buildable
    {
        private static unowned Pomodoro.PreferencesWindow? instance;

        private GLib.Settings       settings;

        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild]
        private unowned Adw.NavigationSplitView split_view;
        [GtkChild]
        private unowned Adw.HeaderBar content_headerbar;
        [GtkChild]
        private unowned Adw.NavigationPage content_page;
        [GtkChild]
        private unowned Gtk.Stack stack;

        [CCode (notify = false)]
        public unowned Gtk.StackPage? visible_page {
            get {
                return this.stack.visible_child != null
                    ? this.stack.get_page (this.stack.visible_child)
                    : null;
            }
        }

        [CCode (notify = false)]
        public string visible_page_name {
            get {
                return this.stack.visible_child_name;
            }
            set {
                this.stack.visible_child_name = value;
            }
        }

        public static Pomodoro.PreferencesWindow? get_default ()
        {
            return  Pomodoro.PreferencesWindow.instance;
        }

        construct
        {
            PreferencesWindow.instance = this;

            this.settings = Pomodoro.get_settings ();

            this.load_window_state ();

            this.update_title ();
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

        private void update_title ()
        {
            var visible_page = this.visible_page;

            if (visible_page != null) {
                this.content_page.title = visible_page.title;
                this.content_headerbar.show_title = true;
            }
            else {
                this.content_headerbar.show_title = false;
                this.content_page.title = "";
            }
        }

        public void add_toast (owned Adw.Toast toast)
        {
            this.toast_overlay.add_toast (toast);
        }

        [GtkCallback]
        private void on_stack_visible_child_notify (GLib.Object    object,
                                                    GLib.ParamSpec pspec)
        {
            this.split_view.show_content = true;
            this.update_title ();

            this.notify_property ("visible-page");
            this.notify_property ("visible-page-name");
        }

        public override void unmap ()
        {
            this.save_window_state ();

            base.unmap ();
        }

        public override void dispose ()
        {
            base.dispose ();

            if (PreferencesWindow.instance == this) {
                PreferencesWindow.instance = null;
            }
        }
    }
}
