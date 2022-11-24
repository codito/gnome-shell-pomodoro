
namespace Pomodoro
{
    private inline Gtk.StackPage? get_stack_page_by_name (Gtk.Stack stack,
                                                          string name)
    {
        return stack.get_page (stack.get_child_by_name (name));
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-control-buttons.ui")]
    public class TimerControlButtons : Gtk.Box, Gtk.Buildable
    {
        private const uint FADE_IN_DURATION = 500;
        private const uint FADE_OUT_DURATION = 500;

        public bool has_rewind {
            get {
                return this.left_button.visible;
            }
            set {
                this.left_button.visible = value;
            }
        }

        public bool has_suggested_action {
            get {
                return this.center_button.has_css_class ("suggested-action");
            }
            set {
                if (value) {
                    this.center_button.add_css_class ("suggested-action");
                }
                else {
                    this.center_button.remove_css_class ("suggested-action");
                }
            }
        }

        public bool circular {
            get {
                return this.center_button.has_css_class ("circular");
            }
            set {
                if (value) {
                    this.left_button.add_css_class ("circular");
                    this.center_button.add_css_class ("circular");
                    this.right_button.add_css_class ("circular");
                }
                else {
                    this.left_button.remove_css_class ("circular");
                    this.center_button.remove_css_class ("circular");
                    this.right_button.remove_css_class ("circular");
                }
            }
        }

        [GtkChild]
        private unowned Gtk.Button left_button;
        [GtkChild]
        private unowned Gtk.Button center_button;
        [GtkChild]
        private unowned Gtk.Button right_button;
        [GtkChild]
        private unowned Gtk.Stack center_image_stack;
        [GtkChild]
        private unowned Gtk.Stack right_image_stack;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private ulong                   timer_state_changed_id = 0;
        private Adw.TimedAnimation?     fade_animation;


        static construct
        {
            set_css_name ("timercontrolbuttons");
        }

        construct
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;

            // Right button should mirror the opacity of left button.
            this.left_button.bind_property ("opacity", this.right_button, "opacity");
        }

        private void fade_in ()
        {
            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            if (!this.get_mapped ()) {
                this.left_button.opacity = 1.0;
                return;
            }

            if (this.left_button.opacity == 1.0) {
                return;
            }

            var animation_target = new Adw.PropertyAnimationTarget (this.left_button, "opacity");

            this.fade_animation = new Adw.TimedAnimation (this.left_button,
                                                          this.left_button.opacity,
                                                          1.0,
                                                          FADE_IN_DURATION,
                                                          animation_target);
            this.fade_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
            this.fade_animation.play ();
        }

        private void fade_out ()
        {
            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            if (!this.get_mapped ()) {
                this.left_button.opacity = 0.0;
                return;
            }

            if (this.left_button.opacity == 0.0) {
                return;
            }

            var animation_target = new Adw.PropertyAnimationTarget (this.left_button, "opacity");

            this.fade_animation = new Adw.TimedAnimation (this.left_button,
                                                          this.left_button.opacity,
                                                          0.0,
                                                          FADE_OUT_DURATION,
                                                          animation_target);
            this.fade_animation.set_easing (Adw.Easing.EASE_IN_OUT_CUBIC);
            this.fade_animation.play ();
        }

        private void update_buttons ()
        {
            var current_time_block = this.session_manager.current_time_block;

            var is_started = this.timer.is_started ();
            var is_stopped = !is_started;
            var is_paused = this.timer.is_paused ();
            var is_break = current_time_block != null
                ? current_time_block.state.is_break ()
                : true;

            Gtk.StackPage? center_page = null;
            Gtk.StackPage? right_page = null;

            if (is_stopped) {
                center_page = get_stack_page_by_name (this.center_image_stack, "start");

                assert (center_page != null);

                this.fade_out ();
            }
            else {
                if (is_paused) {
                    center_page = get_stack_page_by_name (this.center_image_stack, "resume");
                    right_page = get_stack_page_by_name (this.right_image_stack, "reset");
                }
                else {
                    center_page = get_stack_page_by_name (this.center_image_stack, "pause");
                    right_page = get_stack_page_by_name (this.right_image_stack, "skip");
                }

                assert (center_page != null);
                assert (right_page != null);

                this.fade_in ();
            }

            if (center_page != null) {
                this.center_image_stack.visible_child = center_page.child;
                this.center_button.action_name = "timer.%s".printf (center_page.name);
                this.center_button.tooltip_text = center_page.title;
            }

            if (right_page != null) {
                if (this.right_button.opacity > 0.0) {
                    this.right_image_stack.visible_child = right_page.child;
                }
                else {
                    this.right_image_stack.set_visible_child_full (right_page.name, Gtk.StackTransitionType.NONE);
                }

                this.right_button.action_name = "timer.%s".printf (right_page.name);
                this.right_button.tooltip_text = right_page.name == "skip"
                    ? (is_break ? _("Start pomodoro") : _("Take a break"))
                    : right_page.title;
            }

            this.left_button.can_focus = is_started;
            this.right_button.can_focus = is_started;
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.update_buttons ();
        }

        private void connect_signals ()
        {
            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this.timer.state_changed.connect (this.on_timer_state_changed);
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        public override void map ()
        {
            this.update_buttons ();

            this.connect_signals ();

            base.map ();
        }

        public override void unmap ()
        {
            if (this.fade_animation != null) {
                this.fade_animation.pause ();
                this.fade_animation = null;
            }

            this.disconnect_signals ();

            base.unmap ();
       }

        public override void dispose ()
        {
            this.disconnect_signals ();

            base.dispose ();
        }
    }
}
