
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-label.ui")]
    public class TimerLabel : Adw.Bin, Gtk.Buildable
    {
        private const uint BLINK_DURATION = 1000;
        private const double BLINK_FADE_VALUE = 0.2;

        public unowned Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            set {
                if (value == this._timer) {
                    return;
                }

                this.disconnect_signals ();

                this._timer = value;

                if (this.get_mapped ()) {
                    this.connect_signals ();
                }
            }
        }

        [GtkChild]
        private unowned Gtk.Stack               stack;
        [GtkChild]
        private unowned Gtk.Box                 box;
        [GtkChild]
        private unowned Gtk.Box                 placeholder_box;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel placeholder_seconds_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel minutes_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel separator_label;
        [GtkChild]
        private unowned Pomodoro.MonospaceLabel seconds_label;

        private Pomodoro.Timer          _timer;
        private ulong                   timer_state_changed_id = 0;
        private ulong                   timer_tick_id = 0;
        private Adw.TimedAnimation?     blink_animation;


        static construct
        {
            set_css_name ("timerlabel");
        }

        construct
        {
            this._timer = Pomodoro.Timer.get_default ();
        }

        private void set_default_direction_ltr ()
        {
            this.placeholder_box.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_separator_label.set_direction (Gtk.TextDirection.LTR);
            this.placeholder_seconds_label.set_direction (Gtk.TextDirection.LTR);

            this.box.set_direction (Gtk.TextDirection.LTR);
            this.minutes_label.set_direction (Gtk.TextDirection.LTR);
            this.separator_label.set_direction (Gtk.TextDirection.LTR);
            this.seconds_label.set_direction (Gtk.TextDirection.LTR);
        }

        private void update_visible_child ()
        {
            if (this._timer.is_started ())
            {
                if (this._timer.is_paused ()) {
                    this.start_blinking_animation ();
                }
                else {
                    this.stop_blinking_animation ();
                }

                this.stack.visible_child_name = "running";
            }
            else {
                this.stack.visible_child_name = "stopped";
            }
        }

        private void update_remaining_time (int64 timestamp = -1)
        {
            var remaining = this._timer.calculate_remaining (timestamp);
            var remaining_uint = Pomodoro.Timestamp.to_seconds_uint (remaining);
            var minutes_uint = remaining_uint / 60;
            var seconds_uint = remaining_uint % 60;

            // TODO: hours

            this.minutes_label.text = "%02u".printf (minutes_uint);
            this.seconds_label.text = "%02u".printf (seconds_uint);
        }

        private void start_blinking_animation ()
        {
            if (!this.get_mapped ()) {
                return;
            }

            if (this.blink_animation != null &&
                this.blink_animation.alternate &&
                this.blink_animation.state == Adw.AnimationState.PLAYING)
            {
                return;
            }

            if (this.blink_animation != null) {
                this.blink_animation.pause ();
                this.blink_animation = null;
            }

            var animation_target = new Adw.PropertyAnimationTarget (this.box, "opacity");
            var animation = new Adw.TimedAnimation (this.box,
                                                    this.box.opacity, BLINK_FADE_VALUE, BLINK_DURATION,
                                                    animation_target);
            animation.alternate = this.box.opacity == 1.0;
            // animation.follow_enable_animations_setting = false;  // TODO: added in libadwaita 1.3

            if (animation.value_from <= BLINK_FADE_VALUE) {
                animation.value_to = 1.0;
            }

            if (animation.alternate) {
                animation.repeat_count = uint.MAX;
                animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            }
            else {
                animation.easing = Adw.Easing.EASE_OUT_QUAD;
                animation.done.connect (this.start_blinking_animation);
            }

            this.blink_animation = animation;
            this.blink_animation.play ();
        }

        private void stop_blinking_animation ()
        {
            if (this.blink_animation == null) {
                return;
            }

            if (this.get_mapped () && this.box.opacity != 1.0)
            {
                var animation_target = new Adw.PropertyAnimationTarget (this.box, "opacity");
                var animation = new Adw.TimedAnimation (this.box,
                                                        this.box.opacity, 1.0, 500,
                                                        animation_target);
                animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
                // animation.follow_enable_animations_setting = false;  // TODO: added in libadwaita 1.3

                this.blink_animation.reset ();
                this.blink_animation = animation;
                this.blink_animation.play ();
            }
            else {
                this.blink_animation.reset ();
                this.box.opacity = 1.0;
            }
        }

        private void connect_signals ()
        {
            if (this.timer_tick_id == 0) {
                this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);
            }

            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_tick_id != 0) {
                this._timer.disconnect (this.timer_tick_id);
                this.timer_tick_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        private void on_timer_tick (int64 timestamp)
        {
            this.update_remaining_time (timestamp);
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            // Prevent from displaying 0:00 while stopping the timer.
            if (this._timer.is_started ()) {
                this.update_remaining_time (timestamp);
            }

            this.update_visible_child ();
        }

        public override void map ()
        {
            this.update_remaining_time ();
            this.update_visible_child ();

            this.connect_signals ();

            base.map ();

            if (this._timer.is_paused ()) {
                this.start_blinking_animation ();
            }
        }

        public override void unmap ()
        {
            this.disconnect_signals ();
            this.stop_blinking_animation ();

            base.unmap ();
        }

        public override void realize ()
        {
            this.set_default_direction_ltr ();

            base.realize ();
        }

        public override void dispose ()
        {
            this.disconnect_signals ();
            this.stop_blinking_animation ();

            base.dispose ();
        }
    }
}
