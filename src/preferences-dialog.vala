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
    const double TIMER_SCALE_LOWER = 60.0;
    const double TIMER_SCALE_UPPER = 60.0 * 120.0;

    const double LONG_BREAK_INTERVAL_LOWER = 1.0;
    const double LONG_BREAK_INTERVAL_UPPER = 10.0;

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

    // TODO: refactor code, it can be removed
    private void listbox_foreach (Gtk.ListBox            listbox,
                                  Gtk.ListBoxForeachFunc func)
    {
        var selection_mode = listbox.selection_mode;

        listbox.selection_mode = Gtk.SelectionMode.MULTIPLE;
        listbox.select_all ();
        listbox.selected_foreach (func);
        listbox.unselect_all ();
        listbox.selection_mode = selection_mode;
    }

    public interface PreferencesDialogExtension : Peas.ExtensionBase
    {
    }

    public interface PreferencesPage : Gtk.Widget
    {
        public unowned Pomodoro.PreferencesDialog get_preferences_dialog ()
        {
            return this.root as Pomodoro.PreferencesDialog;
        }

        public virtual void configure_header_bar (Gtk.HeaderBar header_bar)
        {
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/preferences-keyboard-shortcut-page.ui")]
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
        private ulong key_press_event_id = 0;
        private ulong key_release_event_id = 0;
        private ulong focus_out_event_id = 0;
        private GLib.List<unowned Gtk.Label> preview_labels;

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

            while (!this.preview_labels.is_empty ()) {
                var link = this.preview_labels.first ();
                this.preview_labels.remove_link (link);
                link.data.destroy ();
            }

            foreach (var element in this.accelerator.get_keys ())
            {
                if (index > 0) {
                    var separator_label = new Gtk.Label ("+");
                    this.preview_box.prepend (separator_label);
                    this.preview_labels.append (separator_label);
                }

                var key_label = new Gtk.Label (element);
                key_label.valign = Gtk.Align.CENTER;
                key_label.get_style_context ().add_class ("key");

                this.preview_box.prepend (key_label);
                this.preview_labels.append (key_label);

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

            var root = (Gtk.Widget) this.root;

            if (this.key_press_event_id == 0) {
                this.key_press_event_id = root.key_press_event.connect (this.on_key_press_event);
            }

            if (this.key_release_event_id == 0) {
                this.key_release_event_id = root.key_release_event.connect (this.on_key_release_event);
            }

            if (this.focus_out_event_id == 0) {
                this.focus_out_event_id = root.focus_out_event.connect (this.on_focus_out_event);
            }

            var application = Pomodoro.Application.get_default ();
            application.capabilities.disable ("accelerator");
        }

        public override void unmap ()
        {
            base.unmap ();

            var root = (Gtk.Widget) this.root;

            if (this.key_press_event_id != 0) {
                root.key_press_event.disconnect (this.on_key_press_event);
                this.key_press_event_id = 0;
            }

            if (this.key_release_event_id != 0) {
                root.key_release_event.disconnect (this.on_key_release_event);
                this.key_release_event_id = 0;
            }

            if (this.focus_out_event_id != 0) {
                root.focus_out_event.disconnect (this.on_focus_out_event);
                this.focus_out_event_id != 0;
            }

            var application = Pomodoro.Application.get_default ();
            application.capabilities.enable ("accelerator");
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/preferences-plugins-page.ui")]
    public class PreferencesPluginsPage : Gtk.ScrolledWindow, Gtk.Buildable, Pomodoro.PreferencesPage
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
            foreach (var name in Pomodoro.Application.LEGACY_PLUGINS)
            {
                if (name == plugin_name) {
                    return true;
                }
            }

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

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/preferences-main-page.ui")]
    public class PreferencesMainPage : Gtk.ScrolledWindow, Gtk.Buildable, Pomodoro.PreferencesPage
    {
        [GtkChild]
        public unowned Gtk.Box box;
        [GtkChild]
        public unowned Gtk.ListBox timer_listbox;
        [GtkChild]
        public unowned Gtk.ListBox notifications_listbox;
        [GtkChild]
        public unowned Gtk.ListBox desktop_listbox;
        [GtkChild]
        public unowned Gtk.ListBox plugins_listbox;
        [GtkChild]
        public unowned Gtk.SizeGroup lisboxrow_sizegroup;

        [GtkChild]
        private unowned Gtk.ListBoxRow listboxrow_accelerator;
        [GtkChild]
        private unowned Gtk.ListBoxRow listboxrow_idle_monitor;

        private GLib.Settings settings;
        private Pomodoro.Accelerator accelerator;

        construct
        {
            this.timer_listbox.set_header_func (Pomodoro.list_box_separator_func);
            this.notifications_listbox.set_header_func (Pomodoro.list_box_separator_func);
            this.desktop_listbox.set_header_func (Pomodoro.list_box_separator_func);
            this.plugins_listbox.set_header_func (Pomodoro.list_box_separator_func);

            var application = Pomodoro.Application.get_default ();
            application.capabilities.capability_enabled.connect (this.on_capability_enabled);
            application.capabilities.capability_disabled.connect (this.on_capability_disabled);

            this.update_capabilities ();

            /* hide frame if empty */
            this.setup_listbox (this.desktop_listbox);
        }

        private unowned Widgets.LogScale setup_time_scale (Gtk.Builder builder,
                                                           string      grid_name,
                                                           string      label_name)
        {
            var adjustment = new Gtk.Adjustment (0.0,
                                                 TIMER_SCALE_LOWER,
                                                 TIMER_SCALE_UPPER,
                                                 60.0,
                                                 300.0,
                                                 0.0);

            var scale = new Widgets.LogScale (adjustment, 2.0);

            var grid = builder.get_object (grid_name) as Gtk.Grid;
            grid.attach (scale, 0, 1, 2, 1);

            var label = builder.get_object (label_name) as Gtk.Label;
            adjustment.value_changed.connect (() => {
                label.set_text (format_time ((int) adjustment.value));
            });

            adjustment.value_changed ();

            unowned Widgets.LogScale unowned_scale = scale;

            return unowned_scale;
        }

        private void setup_timer_section (Gtk.Builder builder)
        {
            var pomodoro_scale = this.setup_time_scale
                                       (builder,
                                        "pomodoro_grid",
                                        "pomodoro_label");
            var short_break_scale = this.setup_time_scale
                                       (builder,
                                        "short_break_grid",
                                        "short_break_label");
            var long_break_scale = this.setup_time_scale
                                       (builder,
                                        "long_break_grid",
                                        "long_break_label");
            var long_break_interval_spinbutton = builder.get_object
                                       ("long_break_interval_spinbutton")
                                       as Gtk.SpinButton;
            var accelerator_label = builder.get_object
                                       ("accelerator_label")
                                       as Gtk.Label;

            this.settings.bind ("pomodoro-duration",
                                pomodoro_scale.base_adjustment,
                                "value",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("short-break-duration",
                                short_break_scale.base_adjustment,
                                "value",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("long-break-duration",
                                long_break_scale.base_adjustment,
                                "value",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("long-break-interval",
                                long_break_interval_spinbutton.adjustment,
                                "value",
                                GLib.SettingsBindFlags.DEFAULT);

            this.accelerator = new Pomodoro.Accelerator ();
            this.accelerator.changed.connect (() => {
                accelerator_label.label = this.accelerator.display_name != ""
                        ? this.accelerator.display_name : _("Off");
            });
            this.settings.bind_with_mapping
                                       ("toggle-timer-key",
                                        this.accelerator,
                                        "name",
                                        GLib.SettingsBindFlags.DEFAULT,
                                        (GLib.SettingsBindGetMappingShared) get_accelerator_mapping,
                                        (GLib.SettingsBindSetMappingShared) set_accelerator_mapping,
                                        null,
                                        null);
        }

        private void setup_notifications_section (Gtk.Builder builder)
        {
            this.settings.bind ("show-screen-notifications",
                                builder.get_object ("screen_notifications_toggle"),
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
        }

        private void setup_other_section (Gtk.Builder builder)
        {
            var pause_when_idle_toggle = builder.get_object ("pause_when_idle_toggle")
                                                             as Gtk.Switch;

            this.settings.bind ("pause-when-idle",
                                pause_when_idle_toggle,
                                "active",
                                GLib.SettingsBindFlags.DEFAULT);
        }

        private void setup_plugins_section (Gtk.Builder builder)
        {
        }

        private void parser_finished (Gtk.Builder builder)
        {
            this.settings = Pomodoro.get_settings ()
                                    .get_child ("preferences");

            base.parser_finished (builder);

            this.setup_timer_section (builder);
            this.setup_notifications_section (builder);
            this.setup_other_section (builder);
            this.setup_plugins_section (builder);
        }

        [GtkCallback]
        private void on_row_activated (Gtk.ListBox    listbox,
                                       Gtk.ListBoxRow row)
        {
            var preferences_dialog = this.get_preferences_dialog ();

            switch (row.name)
            {
                case "keyboard-shortcut":
                    preferences_dialog.set_page ("keyboard-shortcut");
                    break;

                case "plugins":
                    preferences_dialog.set_page ("plugins");
                    break;

                default:
                    break;
            }
        }

        private void update_capabilities ()
        {
            var application  = Pomodoro.Application.get_default ();
            var capabilities = application.capabilities;

            this.listboxrow_accelerator.visible = capabilities.has_enabled ("accelerator");
            this.listboxrow_idle_monitor.visible = capabilities.has_enabled ("idle-monitor");
        }

        private void on_capability_enabled (string capability_name)
        {
            this.update_capabilities ();
        }

        private void on_capability_disabled (string capability_name)
        {
            this.update_capabilities ();
        }

        private void setup_listbox (Gtk.ListBox listbox)
        {
            // // TODO: refactor this, UI should be statically defined
            // listbox_foreach (listbox, (listbox_, row) => {
            //     this.on_listbox_add (listbox as Gtk.Widget, row as Gtk.Widget);
            // });

            // listbox.add.connect_after (this.on_listbox_add);
            // listbox.remove.connect_after (this.on_listbox_remove);
        }

        private void on_listboxrow_visible_notify (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            var widget = object as Gtk.Widget;
            if (widget.parent == null) {
                return;
            }

            var listbox = widget as Gtk.ListBox;
            var visible = false;

            if (widget.parent != null)
            {
                // TODO: this is horrible
                // TODO: refactor this, UI should be statically defined
                listbox_foreach (listbox, (listbox_, row) => {
                    visible |= child.visible;
                });

                if (widget.parent.visible != visible) {
                    widget.parent.visible = visible;
                }
            }
        }

        // /* Note that the "add" signal is not emmited when calling insert() */
        // private void on_listbox_add (Gtk.Widget widget,
        //                              Gtk.Widget child)
        // {
        //     child.notify["visible"].connect (this.on_listboxrow_visible_notify);
        //
        //     if (widget.parent != null && !widget.parent.visible && child.visible) {
        //         widget.parent.visible = true;
        //     }
        // }

        // private void on_listbox_remove (Gtk.Widget widget,
        //                                 Gtk.Widget child)
        // {
        //     child.notify["visible"].disconnect (this.on_listboxrow_visible_notify);
        //
        //     if (widget.parent != null)
        //     {
        //         var listbox = widget as Gtk.ListBox;
        //         var visible = false;
        //
        //         // TODO: this is horrible
        //         // TODO: refactor this, UI should be statically defined
        //         listbox_foreach (listbox, (listbox_, row) => {
        //             visible |= child.visible;
        //         });
        //
        //         if (widget.parent.visible != visible) {
        //             widget.parent.visible = visible;
        //         }
        //     }
        // }

        public override void dispose ()
        {
            var application = Pomodoro.Application.get_default ();
            application.capabilities.capability_enabled.disconnect (this.on_capability_enabled);
            application.capabilities.capability_disabled.disconnect (this.on_capability_disabled);

            base.dispose ();
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/preferences.ui")]
    public class PreferencesDialog : Gtk.ApplicationWindow, Gtk.Buildable
    {
        private const int DEFAULT_WIDTH = 600;
        private const int DEFAULT_HEIGHT = 720;

        private const GLib.ActionEntry[] ACTION_ENTRIES = {
            { "back", on_back_activate }
        };

        private static unowned Pomodoro.PreferencesDialog instance;

        [GtkChild]
        private unowned Gtk.HeaderBar header_bar;
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Button back_button;

        private GLib.HashTable<string, PageMeta?> pages;
        private GLib.List<string>                 history;
        private Peas.ExtensionSet                 extensions;

        private struct PageMeta
        {
            GLib.Type type;
            string    name;
            string    title;
        }

        construct
        {
            PreferencesDialog.instance = this;

            this.pages = new GLib.HashTable<string, PageMeta?> (str_hash, str_equal);

            this.add_page ("main",
                           _("Preferences"),
                           typeof (Pomodoro.PreferencesMainPage));

            this.add_page ("plugins",
                          _("Plugins"),
                          typeof (Pomodoro.PreferencesPluginsPage));

            this.add_page ("keyboard-shortcut",
                          _("Keyboard Shortcut"),
                          typeof (Pomodoro.PreferencesKeyboardShortcutPage));

            this.add_action_entries (PreferencesDialog.ACTION_ENTRIES, this);

            this.history_clear ();

            this.set_page ("main");

            /* let page be modified by extensions */
            this.extensions = new Peas.ExtensionSet (Peas.Engine.get_default (),
                                                     typeof (Pomodoro.PreferencesDialogExtension));

            this.stack.notify["visible-child"].connect (this.on_visible_child_notify);

            this.on_visible_child_notify ();
        }

        ~PreferencesDialog ()
        {
            PreferencesDialog.instance = this;
        }

        public static PreferencesDialog? get_default ()
        {
            return PreferencesDialog.instance;
        }

        public void parser_finished (Gtk.Builder builder)
        {
            base.parser_finished (builder);
        }

        private void on_page_notify (Pomodoro.PreferencesPage page)
        {
            string name;
            string title;

            this.stack.child_get (page,
                                  "name", out name,
                                  "title", out title);
            this.history_push (name);

            var title_label = this.header_bar.title_widget as Gtk.Label;
            if (title_label != null) {
                title_label.label = title;
            }

            this.back_button.visible = this.history.length () > 1;

            if (this.back_button.parent == (Gtk.Widget) this.header_bar) {
                this.back_button.unparent ();
            }

            page.configure_header_bar (this.header_bar);
        }

        private void on_visible_child_notify ()
        {
            var window_width = 0;
            var window_height = 0;
            var header_bar_height = 0;
            var page_height = 0;
            var page = this.stack.visible_child as Pomodoro.PreferencesPage;

            this.on_page_notify (page);

            window_width = this.get_size (Gtk.Orientation.HORIZONTAL);
            window_height = this.get_size (Gtk.Orientation.VERTICAL);

            /* calculate window size */
            this.header_bar.get_preferred_height (null,
                                                  out header_bar_height);

            page.get_preferred_height_for_width (window_width,
                                                 null,
                                                 out page_height);

            if (page is Gtk.ScrolledWindow) {
                var scrolled_window = page as Gtk.ScrolledWindow;
                scrolled_window.set_min_content_height (int.min (page_height, DEFAULT_HEIGHT));

                // TODO: the dialog needs to be redesigned, so that changing its height is no longer needed
                // this.resize (window_width, header_bar_height + DEFAULT_HEIGHT);
            }
            else {
                // TODO: the dialog needs to be redesigned, so that changing its height is no longer needed
                // this.resize (window_width, header_bar_height + page_height);
            }
        }

        private void on_back_activate (GLib.SimpleAction action,
                                       GLib.Variant?     parameter)
        {
            this.history_pop ();
        }

        public unowned Pomodoro.PreferencesPage? get_page (string name)
        {
            if (this.stack != null) {
                var page_widget = this.stack.get_child_by_name (name);

                if (page_widget != null) {
                    return page_widget as Pomodoro.PreferencesPage;
                }
            }

            if (this.pages != null && this.pages.contains (name)) {
                var meta = this.pages.lookup (name);
                var page = GLib.Object.new (meta.type) as Pomodoro.PreferencesPage;

                this.stack.add_titled (page as Gtk.Widget,
                                       meta.name,
                                       meta.title);

                return page as Pomodoro.PreferencesPage;
            }

            return null;
        }

        private void history_clear ()
        {
            this.history = new GLib.List<string> ();
        }

        private void history_push (string name)
        {
            if (name == "main") {
                this.history_clear ();
            }
            else {
                unowned GLib.List<string> last = this.history.last ();

                /* ignore if last element is the same */
                if (last != null && last.data == name) {
                    return;
                }

                /* go back if previous element is the same */
                if (last != null && last.prev != null && last.prev.data == name) {
                    this.history_pop ();

                    return;
                }
            }

            this.history.append (name);
        }

        private string? history_pop ()
        {
            unowned GLib.List<string> last = this.history.last ();

            string? last_name = null;
            string  next_name = "main";

            if (last != null) {
                last_name = last.data.dup ();

                this.history.delete_link (last);
                last = this.history.last ();
            }

            if (last != null) {
                next_name = last.data.dup ();
            }

            this.set_page (next_name);

            return last_name;
        }

        public void add_page (string    name,
                              string    title,
                              GLib.Type type)
                    requires (type.is_a (typeof (Pomodoro.PreferencesPage)))
        {
            var meta = PageMeta () {
                name = name,
                title = title,
                type = type
            };

            this.pages.insert (name, meta);
        }

        public void remove_page (string name)
        {
            if (this.stack != null)
            {
                var child = this.stack.get_child_by_name (name);

                if (this.stack.get_visible_child_name () == name) {
                    this.set_page ("main");
                }

                if (child != null) {
                    this.stack.remove (child);
                }
            }

            this.pages.remove (name);
        }

        public void set_page (string name)
        {
            var page = this.get_page (name);

            if (page != null) {
                this.stack.set_visible_child_name (name);
            }
            else {
                GLib.warning ("Could not change page to \"%s\"", name);
            }
        }
    }
}
