
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-view.ui")]
    public class TimerView : Gtk.Widget, Gtk.Buildable
    {
        [GtkChild]
        private unowned Gtk.MenuButton timer_state_menubutton;
        [GtkChild]
        private unowned Pomodoro.TimerProgressBar timer_progressbar;
        [GtkChild]
        private unowned Pomodoro.TimerLevelBar session_progressbar;
        [GtkChild]
        private unowned Gtk.Grid buttons_grid;
        [GtkChild]
        private unowned Gtk.Button timer_skip_button;
        [GtkChild]
        private unowned Gtk.GestureClick click_gesture;
        [GtkChild]
        private unowned Gtk.GestureDrag drag_gesture;

        private Pomodoro.Timer timer;
        private ulong          timer_notify_state_id = 0;
        private ulong          timer_notify_is_paused_id = 0;

        construct
        {
            var timer = Pomodoro.Timer.get_default ();

            this.timer = timer;
            this.layout_manager = new Gtk.BinLayout ();

            this.insert_action_group ("timer", this.timer.get_action_group ());
        }

        private void update_css_classes ()
        {
            var is_stopped = this.timer.state is Pomodoro.DisabledState;
            var is_paused = this.timer.is_paused;
            var is_running = !(is_stopped || is_paused);

            if (is_running) {
                this.timer_state_menubutton.add_css_class ("timer-running");
                this.timer_progressbar.add_css_class ("timer-running");
                this.session_progressbar.add_css_class ("timer-running");
            }
            else {
                this.timer_state_menubutton.remove_css_class ("timer-running");
                this.timer_progressbar.add_css_class ("timer-running");
                this.session_progressbar.add_css_class ("timer-running");
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

        private void disconnect_signals ()
        {
            if (this.timer_notify_state_id != 0) {
                this.timer.disconnect (this.timer_notify_state_id);
                this.timer_notify_state_id = 0;
            }

            if (this.timer_notify_is_paused_id != 0) {
                this.timer.disconnect (this.timer_notify_is_paused_id);
                this.timer_notify_is_paused_id = 0;
            }
        }

        private void on_timer_state_notify ()
        {
            switch (this.timer.state.name)
            {
                case "null":
                    this.timer_state_menubutton.label = _("Stopped");
                    break;

                case "pomodoro":
                    this.timer_state_menubutton.label = _("Pomodoro");
                    break;

                case "short-break":
                    this.timer_state_menubutton.label = _("Short Break");
                    break;

                case "long-break":
                    this.timer_state_menubutton.label = _("Long Break");
                    break;

                default:
                    this.timer_state_menubutton.label = "";
                    break;
            }

            if (this.timer.state is Pomodoro.BreakState) {
                this.timer_skip_button.tooltip_text = _("Start pomodoro");
            }
            else {
                this.timer_skip_button.tooltip_text = _("Take a break");
            }

            this.update_css_classes ();
            this.update_buttons_stack ();
        }

        private void on_timer_is_paused_notify ()
        {
            this.update_css_classes ();
            this.update_buttons_stack ();
        }

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

        public override void map ()
        {
            this.on_timer_state_notify ();

            base.map ();

            if (this.timer_notify_state_id == 0) {
                this.timer_notify_state_id = this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            }

            if (this.timer_notify_is_paused_id == 0) {
                this.timer_notify_is_paused_id = this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);
            }
        }

        public override void unmap ()
        {
            base.unmap ();

            this.disconnect_signals ();
       }

        public override void dispose ()
        {
            this.disconnect_signals ();

            base.dispose ();
        }
    }
}
