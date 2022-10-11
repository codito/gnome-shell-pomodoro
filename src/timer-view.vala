
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

        private Pomodoro.Timer          timer;
        private Pomodoro.SessionManager session_manager;
        private ulong                   timer_state_changed_id = 0;
        // private ulong                   timer_notify_is_paused_id = 0;

        construct
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.layout_manager  = new Gtk.BinLayout ();

            this.insert_action_group ("session-manager", new Pomodoro.SessionManagerActionGroup (this.session_manager));
            this.insert_action_group ("timer", new Pomodoro.TimerActionGroup (this.timer));
        }

        private void update_css_classes ()
        {
            if (this.timer.is_running ()) {
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

        private void update_buttons ()
        {
            var is_stopped = !this.timer.is_started ();
            var is_paused = this.timer.is_paused ();
            var current_time_block = this.session_manager.current_time_block;
            var buttons_grid_child = this.buttons_grid.get_first_child ();

            this.timer_state_menubutton.label = current_time_block.state.get_label ();

            if (current_time_block.state.is_break ()) {
                this.timer_skip_button.tooltip_text = _("Start pomodoro");
            }
            else {
                this.timer_skip_button.tooltip_text = _("Take a break");
            }

            while (buttons_grid_child != null)
            {
                var stack = buttons_grid_child as Gtk.Stack;

                if (stack != null)
                {
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

                buttons_grid_child = stack.get_next_sibling ();
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.update_css_classes ();
            this.update_buttons ();
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
            var timer = this.timer;

            this.on_timer_state_changed (timer.state, timer.state);

            base.map ();

            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = timer.state_changed.connect (this.on_timer_state_changed);
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
