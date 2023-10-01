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
    public enum WindowSize
    {
        NORMAL = 0,
        COMPACT = 1,
        TINY = 2;

        public static WindowSize from_string (string? name)
        {
            switch (name)
            {
                case "tiny":
                    return WindowSize.TINY;

                case "compact":
                    return WindowSize.COMPACT;

                default:
                    return WindowSize.NORMAL;
            }
        }

        public string to_string ()
        {
            switch (this)
            {
                case NORMAL:
                    return "normal";

                case COMPACT:
                    return "compact";

                case TINY:
                    return "tiny";

                default:
                    assert_not_reached ();
            }
        }
    }

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

        public string to_string ()
        {
            switch (this)
            {
                case TIMER:
                    return "timer";

                case STATS:
                    return "stats";

                case DEFAULT:
                    return "";

                default:
                    assert_not_reached ();
            }
        }
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/window.ui")]
    public class Window : Adw.ApplicationWindow, Gtk.Buildable
    {
        private const uint TOAST_DISMISS_TIMEOUT = 3;


        [CCode (notify = false)]
        public Pomodoro.WindowSize size {
            get {
                return this._size;
            }
            set {
                if (this._size == value) {
                    return;
                }

                this._size = value;

                this.size_stack.visible_child_name = value.to_string ();
                this.notify_property ("size");
            }
        }

        [CCode (notify = false)]
        public Pomodoro.WindowView view {
            get {
                return this._view;
            }
            set {
                if (this._view == value) {
                    return;
                }

                this._view = value;

                var resolved_view = value;
                if (resolved_view == Pomodoro.WindowView.DEFAULT) {
                    resolved_view = this.get_default_view ();
                }

                this.view_stack.visible_child_name = resolved_view.to_string ();
                this.notify_property ("view");
            }
        }

        [GtkChild]
        private unowned Pomodoro.SizeStack size_stack;
        [GtkChild]
        private unowned Adw.ViewStack view_stack;
        [GtkChild]
        private unowned Adw.ToastOverlay toast_overlay;
        [GtkChild]
        private unowned Pomodoro.TimerView timer_view;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private Pomodoro.WindowSize     _size = Pomodoro.WindowSize.NORMAL;
        private Pomodoro.WindowView     _view = Pomodoro.WindowView.DEFAULT;

        construct
        {
            // TODO: this.default_page should be set from application.vala
            // var application = Pomodoro.Application.get_default ();

            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.timer.state_changed.connect (() => {
                this.update_timer_indicator ();
            });

            this.insert_action_group ("session-manager", new Pomodoro.SessionManagerActionGroup ());
            this.insert_action_group ("timer", new Pomodoro.TimerActionGroup ());

            this.update_title ();
            this.update_timer_indicator ();
        }

        private void update_title ()
        {
            var page = this._size == Pomodoro.WindowSize.NORMAL
                ? this.view_stack.get_page (this.view_stack.visible_child)
                : null;

            this.title = page != null ? page.title : _("Pomodoro");
        }

        private void update_timer_indicator ()
        {
            var timer_page = this.view_stack.get_page (this.timer_view);
            var timer      = Pomodoro.Timer.get_default ();

            timer_page.needs_attention = this.view_stack.visible_child != timer_page.child &&
                                         timer.is_started ();
        }

        public Pomodoro.WindowView get_default_view ()
                                                     ensures (result != Pomodoro.WindowView.DEFAULT)
        {
            return Pomodoro.WindowView.TIMER;
        }

        /**
         *  Keep the toast until window is focused.
         */
        private void dismiss_toast_once_focused (Adw.Toast toast)
        {
            toast.timeout = 0;

            var state_flags_changed_id = this.state_flags_changed.connect (
                (previous_state_flags) => {
                    var is_backdrop = Gtk.StateFlags.BACKDROP in this.get_state_flags ();

                    if (!is_backdrop) {
                        toast.timeout = TOAST_DISMISS_TIMEOUT;
                        this.toast_overlay.add_toast (toast);  // necessary for updating the timeout
                    }
                }
            );

            toast.dismissed.connect (() => {
                if (state_flags_changed_id != 0) {
                    this.disconnect (state_flags_changed_id);
                    state_flags_changed_id = 0;
                }
            });
        }

        /**
         * Monitor user activity and dismiss notification once user becomes active.
         */
        private void dismiss_toast_once_user_becomes_active (Adw.Toast toast)
        {
            // toast.timeout = 0;

            // TODO
        }

        public void add_toast (owned Adw.Toast toast)
        {
            if (toast.timeout != 0 && this._size == Pomodoro.WindowSize.NORMAL)
            {
                if (Gtk.StateFlags.BACKDROP in this.get_state_flags ()) {
                    this.dismiss_toast_once_focused (toast);
                }
                else {
                    this.dismiss_toast_once_user_becomes_active (toast);
                }
            }

            this.toast_overlay.add_toast (toast);
        }

        [GtkCallback]
        private void on_size_stack_visible_child_notify (GLib.Object    object,
                                                         GLib.ParamSpec pspec)
        {
            this.size = Pomodoro.WindowSize.from_string (this.size_stack.visible_child_name);
        }

        [GtkCallback]
        private void on_view_stack_visible_child_notify (GLib.Object    object,
                                                         GLib.ParamSpec pspec)
        {
            var view = Pomodoro.WindowView.from_string (this.view_stack.visible_child_name);

            this._view = this._view == Pomodoro.WindowView.DEFAULT && this.get_default_view () == view
                ? Pomodoro.WindowView.DEFAULT
                : view;

            this.update_title ();
            this.update_timer_indicator ();
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

        private void on_shrink_activate (GLib.SimpleAction action,
                                         GLib.Variant?     parameter)
        {
            this.size = Pomodoro.WindowSize.COMPACT;
        }

        private void on_expand_activate (GLib.SimpleAction action,
                                         GLib.Variant?     parameter)
        {
            this.size = Pomodoro.WindowSize.NORMAL;
            this.view = Pomodoro.WindowView.TIMER;
        }

        private void on_toggle_shrinked_activate (GLib.SimpleAction action,
                                                  GLib.Variant?     parameter)
        {
            if (this.size == Pomodoro.WindowSize.NORMAL) {
                this.lookup_action ("shrink").activate (null);
            }
            else {
                this.lookup_action ("expand").activate (null);
            }
        }

        private void setup_actions ()
        {
            var action_map = (GLib.ActionMap) this;

            GLib.SimpleAction action;

            action = new GLib.SimpleAction ("shrink", null);
            action.activate.connect (this.on_shrink_activate);
            action_map.add_action (action);

            action = new GLib.SimpleAction ("expand", null);
            action.activate.connect (this.on_expand_activate);
            action_map.add_action (action);

            action = new GLib.SimpleAction ("toggle-shrinked", null);
            action.activate.connect (this.on_toggle_shrinked_activate);
            action_map.add_action (action);
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

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/install-extension-dialog.ui")]
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
