
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/timer-view.ui")]
    public class TimerView : Gtk.Widget, Gtk.Buildable
    {
        /**
         * MIN_PADDING and MAX_PADDING are applied to left and right sides and scale according to width.
         *
         * BOTTOM_PADDING aims to counter padding used in state_menubutton.
         */
        private int MIN_PADDING = 24;
        private int MAX_PADDING = 72;
        private int BOTTOM_PADDING = 5;

        /**
         * Size of the outer bounds, not including padding.
         */
        private int MIN_WIDTH = 300;
        private int NAT_WIDTH = 400;
        private int MAX_WIDTH = 450;

        /**
         * Vertical spacing between children.
         */
        private int MIN_SPACING = 12;
        private int NAT_SPACING = 24;
        private int MAX_SPACING = 50;

        /**
         * Relative width of the timer label and session indicator.
         */
        private float INNER_RELATIVE_WIDTH = 0.66f;

        [GtkChild]
        private unowned Gtk.MenuButton state_menubutton;
        [GtkChild]
        private unowned Pomodoro.SessionProgressBar session_progressbar;
        // TODO: make custom widget that will handle opacity animation and wont clip the child actor
        // [GtkChild]
        // private unowned Gtk.Revealer session_progressbar_revealer;
        [GtkChild]
        private unowned Pomodoro.TimerProgressRing timer_progressring;
        [GtkChild]
        private unowned Gtk.Box inner_box;
        [GtkChild]
        private unowned Pomodoro.TimerControlButtons timer_control_buttons;
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

            this.timer_progressring.bind_property ("line-width", this.session_progressbar, "line-width", GLib.BindingFlags.SYNC_CREATE);
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
            this.state_menubutton.label = !this.timer.is_finished ()
                ? this.get_state_label ()
                : _("Finished!");
        }

        private void update_session_progressbar ()
        {
            // this.session_progressbar_revealer.reveal_child = !this.session_manager.has_uniform_breaks;
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
            toast.use_markup = false;
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

        private void calculate_height_for_width (int     avaliable_width,
                                                 out int minimum_height,
                                                 out int natural_height)
        {
            var tmp_minimum_height = 0;
            var tmp_natural_height = 0;

            minimum_height = 2 * MIN_SPACING;
            natural_height = 2 * NAT_SPACING;

            this.state_menubutton.measure (Gtk.Orientation.VERTICAL,
                                           avaliable_width,
                                           out tmp_minimum_height,
                                           out tmp_natural_height,
                                           null,
                                           null);
            minimum_height += tmp_minimum_height;
            natural_height += tmp_natural_height;

            this.timer_progressring.measure (Gtk.Orientation.VERTICAL,
                                             avaliable_width,
                                             out tmp_minimum_height,
                                             out tmp_natural_height,
                                             null,
                                             null);
            minimum_height += tmp_minimum_height;
            natural_height += tmp_natural_height;

            this.timer_control_buttons.measure (Gtk.Orientation.VERTICAL,
                                                avaliable_width,
                                                out tmp_minimum_height,
                                                out tmp_natural_height,
                                                null,
                                                null);
            minimum_height += tmp_minimum_height;
            natural_height += tmp_natural_height;
        }

        private void calculate_width_for_height (int     avaliable_height,
                                                 out int minimum_width,
                                                 out int natural_width)
        {
            var tmp_minimum_width = 0;
            var tmp_natural_width = 0;
            var tmp_minimum_height = 0;
            var tmp_natural_height = 0;

            minimum_width = MIN_WIDTH;
            natural_width = MIN_WIDTH;

            avaliable_height -= 2 * NAT_SPACING;

            this.state_menubutton.measure (Gtk.Orientation.HORIZONTAL,
                                           -1,
                                           out tmp_minimum_width,
                                           out tmp_natural_width,
                                           null,
                                           null);
            minimum_width = int.max (minimum_width, tmp_minimum_width);
            natural_width = int.max (natural_width, tmp_natural_width);

            this.state_menubutton.measure (Gtk.Orientation.VERTICAL,
                                           natural_width,
                                           null,
                                           out tmp_natural_height,
                                           null,
                                           null);
            avaliable_height -= tmp_natural_height;

            this.timer_control_buttons.measure (Gtk.Orientation.VERTICAL,
                                                natural_width,
                                                null,
                                                out tmp_natural_height,
                                                null,
                                                null);
            avaliable_height -= tmp_natural_height;

            this.timer_progressring.measure (Gtk.Orientation.HORIZONTAL,
                                             avaliable_height,
                                             null,
                                             out tmp_natural_width,
                                             null,
                                             null);
            natural_width = int.max (natural_width, tmp_natural_width);

            if (natural_width > MAX_WIDTH) {
                natural_width = MAX_WIDTH;
            }
        }

        private int calculate_padding (int width)
        {
            var min_padding = (float) MIN_PADDING;
            var max_padding = (float) MAX_PADDING;
            var t           = ((float) (width - MIN_WIDTH) / (float) MAX_WIDTH).clamp (0.0f, 1.0f);

            return (int) Math.roundf ((1.0f - t) * min_padding + t * max_padding);
        }

        private int calculate_padding_inv (int padded_width)
        {
            var min_padded_width = (float) (MIN_WIDTH + 2 * MIN_PADDING);
            var max_padded_width = (float) (MAX_WIDTH + 2 * MAX_PADDING);
            var t                = (padded_width - min_padded_width) / (max_padded_width - min_padded_width);

            return (int) Math.roundf (2.0f * ((1.0f - t) * (float) MIN_WIDTH + t * (float) MAX_WIDTH)) / 2;
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT;
        }

        /**
         * Define two main guides: outer and inner. Outer is intended as a
         * container for major widgets. Inner is intended for the timer
         * label and session progress bar.
         *
         * The constraints try to fit height of the outer guide to the window.
         * Than its constrained by max width.
         */
        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var minimum_padding = MIN_PADDING;
            var natural_padding = MIN_PADDING;

            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                if (for_size == -1) {
                    minimum = MIN_WIDTH;
                    natural = NAT_WIDTH;
                }
                else {
                    this.calculate_width_for_height (for_size, out minimum, out natural);
                }

                natural_padding = this.calculate_padding (natural);
            }
            else {
                this.calculate_height_for_width (MIN_WIDTH,
                                                 out minimum,
                                                 out minimum);

                if (for_size != -1) {
                    this.calculate_height_for_width (for_size.clamp (MIN_WIDTH, MAX_WIDTH),
                                                     null,
                                                     out natural);
                }
            }

            if (natural < minimum) {
                natural = minimum;
            }

            minimum += minimum_padding * 2;
            natural += natural_padding * 2;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var is_ltr = this.get_direction () != Gtk.TextDirection.RTL;

            // Determine width of the outer bounds.
            var allocation = Gtk.Allocation () {
                width = this.calculate_padding_inv (width).clamp (MIN_WIDTH, MAX_WIDTH),
                height = height - BOTTOM_PADDING
            };
            var tmp_minimum_height = 0;
            var tmp_natural_height = 0;
            var tmp_minimum_width = 0;
            var tmp_natural_width = 0;

            this.calculate_height_for_width (allocation.width, null, out tmp_natural_height);

            if (tmp_natural_height > allocation.height) {
                this.calculate_width_for_height (allocation.height, null, out allocation.width);
            }

            // Determine state_menubutton size.
            var state_menubutton_allocation = Gtk.Allocation ();
            this.state_menubutton.measure (Gtk.Orientation.HORIZONTAL,
                                           -1,
                                           out tmp_minimum_width,
                                           out tmp_natural_width,
                                           null,
                                           null);
            state_menubutton_allocation.width = allocation.width.clamp (tmp_minimum_width, tmp_natural_width);
            this.state_menubutton.measure (Gtk.Orientation.VERTICAL,
                                           state_menubutton_allocation.width,
                                           null,
                                           out state_menubutton_allocation.height,
                                           null,
                                           null);

            // Determine timer_progressring size.
            var timer_progressring_allocation = Gtk.Allocation () {
                width = allocation.width,
                height = allocation.width
            };

            // Determine inner_box size.
            var inner_box_allocation = Gtk.Allocation () {
                width = (int) Math.roundf (timer_progressring_allocation.width * INNER_RELATIVE_WIDTH / 2.0f) * 2,
                height = 0
            };
            this.inner_box.measure (Gtk.Orientation.VERTICAL,
                                    inner_box_allocation.width,
                                    null,
                                    out inner_box_allocation.height,
                                    null,
                                    null);

            // Determine timer_control_buttons size.
            var timer_control_buttons_allocation = Gtk.Allocation ();
            this.timer_control_buttons.measure (Gtk.Orientation.HORIZONTAL,
                                                -1,
                                                out tmp_minimum_width,
                                                out tmp_natural_width,
                                                null,
                                                null);
            timer_control_buttons_allocation.width = int.max(
                                                allocation.width.clamp (tmp_minimum_width, tmp_natural_width),
                                                inner_box_allocation.width + 60);
            this.timer_control_buttons.measure (Gtk.Orientation.VERTICAL,
                                                timer_control_buttons_allocation.width,
                                                null,
                                                out timer_control_buttons_allocation.height,
                                                null,
                                                null);

            // Position children horizontally.
            allocation.x = (width - allocation.width) / 2;
            state_menubutton_allocation.x = is_ltr
                                            ? allocation.x
                                            : allocation.x + allocation.width - state_menubutton_allocation.width;
            timer_progressring_allocation.x = allocation.x;
            inner_box_allocation.x = (width - inner_box_allocation.width) / 2;
            timer_control_buttons_allocation.x = (width - timer_control_buttons_allocation.width) / 2;

            // Position children vertically.
            tmp_natural_height = state_menubutton_allocation.height +
                                 timer_progressring_allocation.height +
                                 timer_control_buttons_allocation.height;
            var spacing = ((height - tmp_natural_height) / 4).clamp (MIN_SPACING, MAX_SPACING);
            allocation.y = (height - tmp_natural_height - 2 * spacing) / 2 - BOTTOM_PADDING;
            state_menubutton_allocation.y = allocation.y;
            timer_progressring_allocation.y = state_menubutton_allocation.y + state_menubutton_allocation.height + spacing;
            inner_box_allocation.y = timer_progressring_allocation.y + (timer_progressring_allocation.height - inner_box_allocation.height) / 2;
            timer_control_buttons_allocation.y = timer_progressring_allocation.y + timer_progressring_allocation.height + spacing;

            this.state_menubutton.allocate_size (state_menubutton_allocation, -1);
            this.timer_progressring.allocate_size (timer_progressring_allocation, -1);
            this.inner_box.allocate_size (inner_box_allocation, -1);
            this.timer_control_buttons.allocate_size (timer_control_buttons_allocation, -1);
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
