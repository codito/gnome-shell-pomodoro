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
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */


namespace Pomodoro
{
    public enum WindowView
    {
        DEFAULT = 0,
        TIMER = 1,
        STATS = 2;

        public static WindowView from_string (string? view_name)
        {
            switch (view_name)
            {
                case "timer":
                    return WindowView.TIMER;

                case "stats":
                    return WindowView.STATS;

                default:
                    return WindowView.DEFAULT;
            }
        }
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/window.ui")]
    public class Window : Adw.ApplicationWindow, Gtk.Buildable
    {
        // private const int MIN_WIDTH = 500;
        // private const int MIN_HEIGHT = 650;

        public Pomodoro.WindowView view {
            get {
                return this._view;
            }
            set {
                this._view = value;

                switch (value)
                {
                    case Pomodoro.WindowView.TIMER:
                        this.stack.visible_child_name = "timer";
                        break;

                    case Pomodoro.WindowView.STATS:
                        this.stack.visible_child_name = "stats";
                        break;

                    default:
                        this.stack.visible_child_name = "timer";
                        break;
                }
            }
        }

        private Pomodoro.WindowView _view = Pomodoro.WindowView.DEFAULT;

        [GtkChild]
        private unowned Gtk.Stack stack;
        // [GtkChild]
        // private unowned Gtk.Revealer revealer;


        construct
        {
            // TODO: this.default_page should be set from application.vala
            // var application = Pomodoro.Application.get_default ();

            // if (application.capabilities.has_capability ("indicator")) {
            //     this.default_page = "stats";
            // }
            // else {
            //     this.default_page = "timer";
            // }

            // this.stack.visible_child_name = this.default_page;
        }

        /*
        [GtkCallback]
        private void on_in_app_notification_install_extension_install_button_clicked (Gtk.Button button)
        {
            this.in_app_notification_install_extension.set_reveal_child (false);

            if (install_extension_callback != null) {
                this.install_extension_callback ();
            }
        }

        [GtkCallback]
        private void on_in_app_notification_install_extension_close_button_clicked (Gtk.Button button)
        {
            this.in_app_notification_install_extension.set_reveal_child (false);

            if (install_extension_dismissed_callback != null) {
                this.install_extension_dismissed_callback ();
            }
        }

        public void show_in_app_notification_install_extension (GLib.Callback? callback,
                                                                GLib.Callback? dismissed_callback = null)
        {
            this.install_extension_callback = callback;
            this.install_extension_dismissed_callback = dismissed_callback;

            this.in_app_notification_install_extension.set_reveal_child (true);
        }

        public void hide_in_app_notification_install_extension ()
        {
            this.in_app_notification_install_extension.set_reveal_child (false);
        }
        */

        public bool shrinked {
            get {
                return this.valign == Gtk.Align.START;
            }
        }

        public void shrink ()
        {
            this.resizable = false;
            this.valign = Gtk.Align.START;
            this.stack.visible = false;

            // TODO: place controls into headerbar
        }

        public void unshrink ()
        {
            this.resizable = true;
            this.valign = Gtk.Align.FILL;
            this.stack.visible = true;
        }

        private void change_shrink_state (GLib.SimpleAction action,
                                          GLib.Variant?     state)
        {
            if (state.get_boolean ()) {
                this.shrink ();
            }
            else {
                this.unshrink ();
            }

            action.set_state (state);
        }

        private void change_dark_theme_state (GLib.SimpleAction action,
                                              GLib.Variant?     state)
        {
            var gtk_settings = Gtk.Settings.get_default ();
            gtk_settings.gtk_application_prefer_dark_theme = state.get_boolean ();

            action.set_state (state);
        }

        private void setup_actions ()
        {
            var action_map = (GLib.ActionMap) this;
            var gtk_settings = Gtk.Settings.get_default ();

            GLib.SimpleAction action;

            action = new GLib.SimpleAction.stateful (
                "shrink", null, new GLib.Variant.boolean (false));
            action.change_state.connect (this.change_shrink_state);
            action_map.add_action (action);
            // this.notify["fullscreened"].connect (() => {  // TODO: does not work
            //     action.set_enabled (!this.fullscreened);
            // });

            action = new GLib.SimpleAction.stateful (
                "dark-theme", null, new GLib.Variant.boolean (gtk_settings.gtk_application_prefer_dark_theme));
            action.change_state.connect (this.change_dark_theme_state);
            action_map.add_action (action);
            // TODO: monitor gtk_application_prefer_dark_theme for changes
        }

        public void parser_finished (Gtk.Builder builder)
        {
            this.setup_actions ();

            base.parser_finished (builder);
        }
    }

    /*
    public enum InstallExtensionDialogResponse
    {
        CANCEL = 0,
        CLOSE = 1,
        MANAGE_EXTENSIONS = 2,
        REPORT_ISSUE = 3
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/install-extension-dialog.ui")]
    public class InstallExtensionDialog : Gtk.Dialog
    {
        private delegate void ForeachChildFunc (Gtk.Widget child);

        [GtkChild]
        private unowned Gtk.Spinner spinner;
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.TextView error_installing_textview;
        [GtkChild]
        private unowned Gtk.TextView error_enabling_textview;
        [GtkChild]
        private unowned Gtk.Button cancel_button;
        [GtkChild]
        private unowned Gtk.Button manage_extensions_button;
        [GtkChild]
        private unowned Gtk.Button report_button;
        [GtkChild]
        private unowned Gtk.Button close_button;
        [GtkChild]
        private unowned Gtk.Button done_button;

        construct
        {
            this.show_in_progress_page ();
        }

        private void foreach_button (ForeachChildFunc func)
        {
            func (this.cancel_button);
            func (this.manage_extensions_button);
            func (this.report_button);
            func (this.close_button);
            func (this.done_button);
        }

        public void show_in_progress_page ()
        {
            this.foreach_button ((button) => {
                if (button.name == "cancel") {
                    button.show ();
                }
                else {
                    button.hide ();
                }
            });

            this.stack.set_visible_child_name ("in-progress");
        }

        public void show_success_page ()
        {
            this.foreach_button ((button) => {
                if (button.name == "manage-extensions" || button.name == "done") {
                    button.show ();
                }
                else {
                    button.hide ();
                }
            });

            this.spinner.spinning = false;
            this.stack.set_visible_child_name ("success");
        }

        public void show_error_page (string error_message)
        {
            this.foreach_button ((button) => {
                if (button.name == "report-issue" || button.name == "close") {
                    button.show ();
                }
                else {
                    button.hide ();
                }
            });

            this.error_installing_textview.buffer.text = error_message;

            this.spinner.spinning = false;
            this.stack.set_visible_child_name ("error-installing");
        }

        public void show_enabling_error_page (string error_message)
        {
            this.foreach_button ((button) => {
                if (button.name == "report-issue" || button.name == "close") {
                    button.show ();
                }
                else {
                    button.hide ();
                }
            });

            this.error_installing_textview.buffer.text = error_message;

            this.spinner.spinning = false;
            this.stack.set_visible_child_name ("error-enabling");
        }
    }
    */
}
