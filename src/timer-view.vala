
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/timer-view.ui")]
    public class TimerView : Gtk.Widget, Gtk.Buildable
    {
        // private const double FADED_IN = 1.0;
        // private const double FADED_OUT = 0.2;

        // private const double TIMER_LINE_WIDTH = 6.0;
        // private const double TIMER_RADIUS = 165.0;

        // private struct Name
        // {
        //     public string name;
        //     public string display_name;
        // }

        // private const Name[] STATE_NAMES = {
        //     { "null", "" },
        //     { "pomodoro", N_("Pomodoro") },
        //     { "short-break", N_("Short Break") },
        //     { "long-break", N_("Long Break") }
        // };

        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.ToggleButton state_togglebutton;
        // [GtkChild]
        // private unowned Gtk.Label minutes_label;
        // [GtkChild]
        // private unowned Gtk.Label seconds_label;
        // [GtkChild]
        // private unowned Gtk.Widget timer_box;
        // [GtkChild]
        // private unowned Gtk.Button pause_button;
        // [GtkChild]
        // private unowned Gtk.Image pause_button_image;
        // [GtkChild]
        // private unowned Gtk.Revealer in_app_notification_install_extension;

            // this.insert_action_group ("timer", this.timer.get_action_group ());

        [GtkChild]
        private unowned Gtk.GestureClick click_gesture;
        [GtkChild]
        private unowned Gtk.GestureDrag drag_gesture;

        private unowned Pomodoro.Timer timer;
        // private Pomodoro.Animation blink_animation;
        // private GLib.Callback? install_extension_callback = null;
        // private GLib.Callback? install_extension_dismissed_callback = null;

        construct
        {
            // this.timer = Pomodoro.Timer.get_default ();

            // this.on_timer_state_notify ();
            // this.on_timer_elapsed_notify ();
            // this.on_timer_is_paused_notify ();

            this.layout_manager = new Gtk.BinLayout ();
        }

        private void on_timer_state_notify ()
        {
            // this.stack.visible_child_name =
            //         (this.timer.state is Pomodoro.DisabledState) ? "disabled" : "enabled";

            // foreach (var mapping in STATE_NAMES)
            // {
            //     if (mapping.name == this.timer.state.name && mapping.display_name != "") {
            //         this.state_togglebutton.label = mapping.display_name;
            //         break;
            //     }
            // }
        }

        /*
        private void on_blink_animation_complete ()
        {
            if (this.timer.is_paused) {
                this.blink_animation.start_with_value (1.0);
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

            if (this.timer.is_paused) {
                this.pause_button_image.icon_name = "media-playback-start-symbolic";
                this.pause_button.action_name     = "timer.resume";
                this.pause_button.tooltip_text    = _("Resume");

                this.blink_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.BLINK,
                                                               2500,
                                                               5);
                this.blink_animation.add_property (this.timer_box,
                                                   "opacity",
                                                   FADED_OUT);
                this.blink_animation.complete.connect (this.on_blink_animation_complete);
                this.blink_animation.start_with_value (1.0);
            }
            else {
                this.pause_button_image.icon_name = "media-playback-pause-symbolic";
                this.pause_button.action_name     = "timer.pause";
                this.pause_button.tooltip_text    = _("Pause");

                this.blink_animation = new Pomodoro.Animation (Pomodoro.AnimationMode.EASE_OUT,
                                                               200,
                                                               50);
                this.blink_animation.add_property (this.timer_box,
                                                   "opacity",
                                                   1.0);
                this.blink_animation.start ();
            }
        }

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

            // var state_togglebutton = builder.get_object ("state_togglebutton");
            // this.state_togglebutton.bind_property ("active",
            //                                   builder.get_object ("state_popover"),
            //                                   "visible",
            //                                   GLib.BindingFlags.BIDIRECTIONAL);

            this.timer = Pomodoro.Timer.get_default ();
            this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            // this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);
            // this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);

            this.on_timer_state_notify ();
            // this.on_timer_elapsed_notify ();
            // this.on_timer_is_paused_notify ();

            this.insert_action_group ("timer", this.timer.get_action_group ());
        }
    }
}
