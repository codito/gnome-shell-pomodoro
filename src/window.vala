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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/window.ui")]
    public class Window : Gtk.ApplicationWindow, Gtk.Buildable
    {
        private const int MIN_WIDTH = 500;
        private const int MIN_HEIGHT = 650;

        private const double FADED_IN = 1.0;
        private const double FADED_OUT = 0.2;

        private const double TIMER_LINE_WIDTH = 6.0;
        private const double TIMER_RADIUS = 165.0;

        private struct Name
        {
            public string name;
            public string display_name;
        }

        private const Name[] STATE_NAMES = {
            { "null", "" },
            { "pomodoro", N_("Pomodoro") },
            { "short-break", N_("Short Break") },
            { "long-break", N_("Long Break") }
        };

        public string mode {
            get {
                return this.stack.visible_child_name;
            }
            set {
                this.stack.visible_child_name = value;
            }
        }

        public string default_mode {
            get {
                return this.default_page;
            }
        }

        private unowned Pomodoro.Timer timer;

        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Stack timer_stack;
        [GtkChild]
        private unowned Gtk.ToggleButton state_togglebutton;
        [GtkChild]
        private unowned Gtk.Label minutes_label;
        [GtkChild]
        private unowned Gtk.Label seconds_label;
        [GtkChild]
        private unowned Gtk.Widget timer_box;
        [GtkChild]
        private unowned Gtk.Button pause_resume_button;
        [GtkChild]
        private unowned Gtk.Image pause_button_image;
        [GtkChild]
        private unowned Gtk.Revealer in_app_notification_install_extension;

        private Pomodoro.Animation blink_animation;
        private string default_page;
        private GLib.Callback? install_extension_callback = null;
        private GLib.Callback? install_extension_dismissed_callback = null;

        construct
        {
            // this.stack.add_titled (this.timer_stack, "timer", _("Timer"));
            this.stack.add_titled (new Pomodoro.StatsView (), "stats", _("Stats"));

            // TODO: this.default_page should be set from application.vala
            var application = Pomodoro.Application.get_default ();

            this.default_page = "timer";

            this.stack.visible_child_name = this.default_page;

            this.on_timer_state_notify ();
            this.on_timer_elapsed_notify ();
            this.on_timer_is_paused_notify ();

            this.update_buttons();
        }

        public void parser_finished (Gtk.Builder builder)
        {
            this.timer = Pomodoro.Timer.get_default ();
            this.insert_action_group ("timer", this.timer.get_action_group ());

            base.parser_finished (builder);

            var state_togglebutton = builder.get_object ("state_togglebutton");
            state_togglebutton.bind_property ("active",
                                              builder.get_object ("state_popover"),
                                              "visible",
                                              GLib.BindingFlags.BIDIRECTIONAL);

            this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);
            this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);
        }

        private void update_buttons ()
        {
            if (this.timer.is_paused) {
                this.pause_resume_image.icon_name = "media-playback-start-symbolic";
                this.pause_resume_button.action_name = "timer.resume";
                this.skip_stop_image.icon_name = "media-playback-stop-symbolic";
                this.skip_stop_button.action_name = "timer.stop";
            }
            else {
                this.pause_resume_image.icon_name = "media-playback-pause-symbolic";
                this.pause_resume_button.action_name = "timer.pause";
                this.skip_stop_image.icon_name = "media-skip-forward-symbolic";
                this.skip_stop_button.action_name = "timer.skip";
            }

            switch (this.timer.state.name)
            {
                case "pomodoro":
                    if (this.timer.is_paused) {
                        this.pause_resume_button.tooltip_text = _("Resume Pomodoro");
                        this.skip_stop_button.tooltip_text = _("Stop");
                    }
                    else {
                        this.pause_resume_button.tooltip_text = _("Pause Pomodoro");
                        this.skip_stop_button.tooltip_text = _("Take a break");
                    }

                    break;

                case "short-break":
                case "long-break":
                    if (this.timer.is_paused) {
                        this.pause_resume_button.tooltip_text = _("Resume break");
                        this.skip_stop_button.tooltip_text = _("Stop");
                    }
                    else {
                        this.pause_resume_button.tooltip_text = _("Pause break");
                        this.skip_stop_button.tooltip_text = _("Start Pomodoro");
                    }
                    break;

                default:
                    break;
            }
        }

        private void on_blink_animation_complete ()
        {
            if (this.timer.is_paused) {
                this.blink_animation.start_with_value (1.0);
            }
        }

        private void on_timer_state_notify ()
        {
            this.timer_stack.visible_child_name =
                    (this.timer.state is Pomodoro.DisabledState) ? "disabled" : "enabled";

            this.update_buttons();

            foreach (var mapping in STATE_NAMES)
            {
                if (mapping.name == this.timer.state.name && mapping.display_name != "") {
                    this.state_togglebutton.label = mapping.display_name;
                    break;
                }
            }
        }

        private void on_timer_elapsed_notify ()
        {
            if (!(this.timer.state is Pomodoro.DisabledState))
            {
                var remaining = (uint) double.max (Math.ceil (this.timer.remaining), 0.0);
                var minutes   = remaining / 60;
                var seconds   = remaining % 60;

                this.minutes_label.label = "%02u".printf (minutes);
                this.seconds_label.label = "%02u".printf (seconds);

                this.timer_box.queue_draw ();
            }
        }

        private void on_timer_is_paused_notify ()
        {
            if (this.blink_animation != null) {
                this.blink_animation.stop ();
                this.blink_animation = null;
            }

            this.update_buttons();

            if (this.timer.is_paused) {
                this.blink_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.BLINK,
                                                               2500,
                                                               25);
                this.blink_animation.add_property (this.timer_box,
                                                   "opacity",
                                                   FADED_OUT);
                this.blink_animation.complete.connect (this.on_blink_animation_complete);
                this.blink_animation.start_with_value (1.0);
            }
            else {
                this.blink_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.EASE_OUT,
                                                               200,
                                                               50);
                this.blink_animation.add_property (this.timer_box,
                                                   "opacity",
                                                   1.0);
                this.blink_animation.start ();
            }
        }

        /*
        [GtkCallback]
        private bool on_timer_box_draw (Gtk.Widget    widget,
                                        Cairo.Context context)
        {
            if (!(this.timer.state is Pomodoro.DisabledState))
            {
                var style_context = widget.get_style_context ();
                var color         = style_context.get_color ();

                var width  = widget.get_allocated_width ();
                var height = widget.get_allocated_height ();
                var x      = 0.5 * width;
                var y      = 0.5 * height;
                var progress = this.timer.state_duration > 0.0
                        ? this.timer.elapsed / this.timer.state_duration : 0.0;

                var angle1 = - 0.5 * Math.PI - 2.0 * Math.PI * progress.clamp (0.000001, 1.0);
                var angle2 = - 0.5 * Math.PI;

                context.set_line_width (TIMER_LINE_WIDTH);

                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * 0.1);
                context.arc (x, y, TIMER_RADIUS, 0.0, 2 * Math.PI);
                context.stroke ();

                context.set_line_cap (Cairo.LineCap.ROUND);
                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha * FADED_IN - (color.alpha * 0.1) * (1.0 - FADED_IN));

                context.arc_negative (x, y, TIMER_RADIUS, angle1, angle2);
                context.stroke ();
            }

            return false;
        }
        */

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
    }

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
}
