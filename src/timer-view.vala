
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-view.ui")]
    public class TimerView : Gtk.Widget, Gtk.Buildable
    {
        // private const double FADED_IN = 1.0;
        // private const double FADED_OUT = 0.2;

        // private const double TIMER_LINE_WIDTH = 6.0;
        // private const double TIMER_RADIUS = 165.0;

        [GtkChild]
        private unowned Gtk.MenuButton timer_state_menubutton;
        [GtkChild]
        private unowned Gtk.Label timer_label;
        [GtkChild]
        private unowned Gtk.Grid buttons_grid;

        // [GtkChild]
        // private unowned Gtk.Revealer in_app_notification_install_extension;
        [GtkChild]
        private unowned Gtk.GestureClick click_gesture;
        [GtkChild]
        private unowned Gtk.GestureDrag drag_gesture;

        private unowned Pomodoro.Timer timer;
        // private GLib.Callback? install_extension_callback = null;
        // private GLib.Callback? install_extension_dismissed_callback = null;

        construct
        {
            this.layout_manager = new Gtk.BinLayout ();
        }

        private void on_timer_elapsed_notify ()
        {
            if (this.timer.state is Pomodoro.DisabledState)
            {
                this.timer_label.label = "25:00";  // TODO: fetch pomodoro duration
            }
            else {
                var remaining = (uint) double.max (Math.ceil (this.timer.remaining), 0.0);
                var minutes   = remaining / 60;
                var seconds   = remaining % 60;

                this.timer_label.label = "%02u:%02u".printf (minutes, seconds);
                // this.timer_box.queue_draw ();
            }
        }

        /**
         * Mainly, e want to update the backdrop. To lower the contrast when timer isn't running.
         */
        private void update_css_classes ()
        {
            var is_stopped = this.timer.state is Pomodoro.DisabledState;
            var is_paused = this.timer.is_paused;

            if (is_stopped || is_paused) {
                this.timer_state_menubutton.remove_css_class ("timer-running");
                this.timer_label.remove_css_class ("timer-running");
            }
            else {
                this.timer_state_menubutton.add_css_class ("timer-running");
                this.timer_label.add_css_class ("timer-running");
            }

            if (is_paused) {
                this.timer_label.add_css_class ("timer-paused");
            }
            else {
                this.timer_label.remove_css_class ("timer-paused");
            }
        }

        private void update_buttons_stack ()
        {
            var is_stopped = this.timer.state is Pomodoro.DisabledState;
            var is_paused = this.timer.is_paused;
            var child = this.buttons_grid.get_first_child ();

            while (child != null) {
                var stack = child as Gtk.Stack;

                if (stack != null) {
                    if (is_stopped) {
                        stack.visible_child_name = "stopped";
                    }
                    else if (is_paused && stack.get_child_by_name ("paused") != null) {
                        stack.visible_child_name = "paused";
                    }
                    else {
                        stack.visible_child_name = "running";
                    }
                }

                child = stack.get_next_sibling ();
            }
        }

        private void on_timer_state_notify ()
        {
            string state_label;

            switch (this.timer.state.name) {
                case "null":
                    state_label = _("Stopped");
                    break;

                case "pomodoro":
                    state_label = _("Pomodoro");
                    break;

                case "short-break":
                    state_label = _("Short Break");
                    break;

                case "long-break":
                    state_label = _("Long Break");
                    break;

                default:
                    state_label = "";
                    break;
            }

            this.timer_state_menubutton.label = state_label;

            this.update_css_classes ();
            this.update_buttons_stack ();
        }

        private void on_timer_is_paused_notify ()
        {
            this.update_css_classes ();
            this.update_buttons_stack ();
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
        private void on_pressed (Gtk.GestureClick gesture,
                                 int              n_press,
                                 double           x,
                                 double           y)
        {
            var sequence = gesture.get_current_sequence ();
            var event = gesture.get_last_event (sequence);

            if (event == null) {
                return;
            }

            if (n_press > 1) {
                this.drag_gesture.set_state (Gtk.EventSequenceState.DENIED);
            }
        }

        [GtkCallback]
        private void on_drag_update (Gtk.GestureDrag gesture,
                                     double          offset_x,
                                     double          offset_y)
        {
            double start_x, start_y;
            double window_x, window_y;
            double native_x, native_y;

            // TODO: use drag_check_threshold_double once available in Vala API
            if (Gtk.drag_check_threshold (this, 0, 0, (int) offset_x, (int) offset_y))
            {
                gesture.set_state (Gtk.EventSequenceState.CLAIMED);
                gesture.get_start_point (out start_x, out start_y);

                var native = this.get_native ();
                gesture.widget.translate_coordinates (
                    native,
                    start_x, start_y,
                    out window_x, out window_y);

                native.get_surface_transform (out native_x, out native_y);
                window_x += native_x;
                window_y += native_y;

                var toplevel = native.get_surface () as Gdk.Toplevel;
                if (toplevel != null) {
                    toplevel.begin_move (
                        gesture.get_device (),
                        (int) gesture.get_current_button (),
                        window_x, window_y,
                        gesture.get_current_event_time ());
                }

                this.drag_gesture.reset ();
                this.click_gesture.reset ();
            }
        }

        public void parser_finished (Gtk.Builder builder)
        {
            base.parser_finished (builder);

            this.timer = Pomodoro.Timer.get_default ();
            this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);
            this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);

            this.on_timer_state_notify ();
            this.on_timer_elapsed_notify ();
            this.on_timer_is_paused_notify ();

            this.insert_action_group ("timer", this.timer.get_action_group ());
        }
    }
}
