
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/timer-view.ui")]
    public class TimerView : Gtk.Widget, Gtk.Buildable
    {
        [GtkChild]
        private unowned Gtk.MenuButton state_menubutton;
        [GtkChild]
        private unowned Pomodoro.SessionProgressBar session_progressbar;
        // TODO: make custom widget that will handle opacity animation and wont clip the child actor
        [GtkChild]
        private unowned Gtk.Revealer session_progressbar_revealer;
        [GtkChild]
        private unowned Gtk.GestureClick click_gesture;
        [GtkChild]
        private unowned Gtk.GestureDrag drag_gesture;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private ulong                   timer_state_changed_id = 0;
        private ulong                   session_manager_notify_has_cycles_id = 0;
        private ulong                   session_expired_id = 0;
        private Adw.Toast?              session_expired_toast;


        static construct
        {
            set_css_name ("timerview");
        }

        construct
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.layout_manager  = new Gtk.BinLayout ();
        }

        private string get_state_label ()
        {
            var current_time_block = this.session_manager.current_time_block;
            var current_state = current_time_block != null ? current_time_block.state : Pomodoro.State.UNDEFINED;

            return current_state.get_label ();
        }

        private void update_css_classes ()
        {
            if (this.timer.is_running ()) {
                this.state_menubutton.add_css_class ("timer-running");
                this.session_progressbar.add_css_class ("timer-running");
            }
            else {
                this.state_menubutton.remove_css_class ("timer-running");
                this.session_progressbar.add_css_class ("timer-running");
            }
        }

        private void update_buttons ()
        {
            this.state_menubutton.label = this.get_state_label ();
        }

        private void update_session_progressbar ()
        {
            this.session_progressbar_revealer.reveal_child = !this.session_manager.has_uniform_breaks;
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.update_css_classes ();
            this.update_buttons ();

            if (this.session_expired_toast != null && this.timer.is_running ()) {
                this.session_expired_toast.dismiss ();
            }
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

        private void on_session_manager_notify_has_cycles ()
        {
            if (this.get_mapped ()) {
                this.update_session_progressbar ();
            }
        }

        /**
         * We want to notify that the app stopped the timer because session has expired.
         * But, its not worth users attention in cases where resetting a session is to be expected.
         */
        private void on_session_expired (Pomodoro.Session session)
        {
            var timestamp = Pomodoro.Timestamp.from_now ();

            // Skip the toast if the timer was stopped and no cycle was completed.
            if (!this.timer.is_started () && !session.has_completed_cycle ()) {
                return;
            }

            // Skip the toast if session expired more than 4 hours ago.
            if (timestamp - session.expiry_time >= 4 * Pomodoro.Interval.HOUR) {
                return;
            }

            var window = this.get_root () as Pomodoro.Window;
            assert (window != null);

            var toast = new Adw.Toast (_("Session has expired"));
            // toast.use_markup = false;  // TODO
            toast.priority = Adw.ToastPriority.HIGH;
            toast.dismissed.connect (() => {
                this.session_expired_toast = null;
            });
            this.session_expired_toast = toast;

            window.add_toast (toast);
        }

        private void connect_signals ()
        {
            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = timer.state_changed.connect (this.on_timer_state_changed);
            }

            if (this.session_manager_notify_has_cycles_id == 0) {
                this.session_manager_notify_has_cycles_id = this.session_manager.notify["has-cycles"].connect (
                            this.on_session_manager_notify_has_cycles);
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            if (this.session_manager_notify_has_cycles_id != 0) {
                this.session_manager.disconnect (this.session_manager_notify_has_cycles_id);
                this.session_manager_notify_has_cycles_id = 0;
            }
        }

        public override void realize ()
        {
            base.realize ();

            this.session_manager.bind_property ("current-session", this.session_progressbar, "session",
                                                GLib.BindingFlags.SYNC_CREATE);
            this.session_expired_id = this.session_manager.session_expired.connect (this.on_session_expired);
        }

        public override void map ()
        {
            this.session_manager.ensure_session ();

            this.update_css_classes ();
            this.update_buttons ();
            this.update_session_progressbar ();

            base.map ();

            this.connect_signals ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.disconnect_signals ();
       }

        public override void dispose ()
        {
            this.disconnect_signals ();

            if (this.session_expired_id != 0) {
                this.session_manager.disconnect (this.session_expired_id);
                this.session_expired_id = 0;
            }

            base.dispose ();
        }
    }
}
