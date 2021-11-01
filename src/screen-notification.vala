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
    /**
     * A fullscreen notification.
     *
     * If idle_monitor is available, window blocks input events after user becomes idle for 600ms.
     * Otherwise, delay blocking until window is shown.
     *
     */
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/screen-notification.ui")]
    public class ScreenNotification : Gtk.Window, Gtk.Buildable
    {
        private const uint IDLE_TIME_TO_CLOSE = 600;
        private const uint MIN_DISPLAY_TIME = 500;
        private const uint FADE_IN_TIME = 180;
        private const uint FADE_OUT_TIME = 180;
        private const uint MOTION_DISTANCE_TO_CLOSE = 20;

        /* TODO: integrate with Gnome.IdleMonitor, open again when idle */
        /* TODO: support multi-screen setup */

        /**
         * Sets whether window capures events.
         *
         * If pass_through is true then we can't capture events.
         */
        private bool pass_through {
            get {
                return this._pass_through;
            }
            set {
                this.do_set_pass_through (value);
            }
        }

        private bool close_on_activity { get; set; default = false; }

        [GtkChild]
        private unowned Gtk.Label minutes_label;
        [GtkChild]
        private unowned Gtk.Label seconds_label;

        // private uint                   fade_in_timeout_id   = 0;
        // private uint                   fade_out_timeout_id  = 0;
        private unowned Pomodoro.Timer timer;
        private ulong                  timer_elapsed_id     = 0;
        private uint                   close_on_activity_id = 0;
        private uint32                 last_event_time      = 0;
        private double                 last_motion_x        = -1.0;
        private double                 last_motion_y        = -1.0;
        private bool                   _pass_through        = true;

        construct
        {
            this.timer = Pomodoro.Timer.get_default ();
            this.timer.state_changed.connect (this.on_timer_state_changed);

            this.on_timer_state_changed ();

            this.fullscreen ();
        }

        ~ScreenNotification ()
        {
            this.unschedule_close_on_activity ();
        }

        private void do_set_pass_through (bool value)
        {
            this._pass_through = value;

            this.last_event_time = (uint32)(GLib.get_real_time () / 1000);
            this.last_motion_x = -1.0;
            this.last_motion_y = -1.0;

            // TODO: Not sure it this works. Other proposals:
            //       1. The old way would involve Gdk.Surface.set_input_region(),
            //          `.get_native().get_surface ()`
            //       2. Use CSS to disable events
            this.can_target = !value;

            // var surface = this.get_native().get_surface ();
            // surface.set_input_region (value ? new Cairo.Region () : null);

            if (this.get_realized ()) {
                this.set_cursor (value ? null : new Gdk.Cursor.from_name ("none", null));
            }
        }

        // public override void realize ()
        // {
        //     base.realize ();
        //
        //     this.do_set_pass_through (this.pass_through);
        //
        //     // var window = this.get_window ();
        //     // window.set_fullscreen_mode (Gdk.FullscreenMode.CURRENT_MONITOR);
        //     // window.fullscreen_on_monitor (int monitor);
        // }

        // public void parser_finished (Gtk.Builder builder)
        // {
        //     base.parser_finished (builder);
        //
        //     var style_context = this.get_style_context ();
        //     style_context.add_class ("hidden");
        // }

        private void on_timer_state_changed ()
        {
            if (this.timer_elapsed_id != 0) {
                this.timer.disconnect (this.timer_elapsed_id);
                this.timer_elapsed_id = 0;
            }

            // TODO: connect to elapsed signal when this widget is visible
            if (this.timer.state is Pomodoro.BreakState) {
                this.timer_elapsed_id = this.timer.notify["elapsed"].connect_after (this.on_timer_elapsed_notify);

                this.on_timer_elapsed_notify ();
            }
        }

        private void on_timer_elapsed_notify ()
        {
            var remaining = (uint) double.max (Math.ceil (this.timer.remaining), 0.0);
            var minutes   = remaining / 60;
            var seconds   = remaining % 60;

            this.minutes_label.label = "%02u".printf (minutes);
            this.seconds_label.label = "%02u".printf (seconds);
        }

        // public override void show ()
        // {
        //     this.fade_in ();
        // }

        // public new void close ()
        // {
        //     this.fade_out ();
        // }

        // private bool on_fade_in_timeout ()
        // {
        //     this.fade_in_timeout_id = 0;
        //     this.pass_through = false;
        //
        //     return false;
        // }

        // private bool on_fade_out_timeout ()
        // {
        //     this.fade_out_timeout_id = 0;
        //
        //     base.close ();
        //
        //     return false;
        // }

        // private void fade_in ()
        // {
        //     if (!this.visible) {
        //         base.show ();
        //     }
        //
        //     /* bring window to focus */
        //     base.present ();
        //
        //     this.get_style_context ().remove_class ("hidden");
        //     this.pass_through = true;
        //
        //     if (this.fade_in_timeout_id == 0) {
        //         this.fade_in_timeout_id = GLib.Timeout.add (FADE_IN_TIME,
        //                                                     this.on_fade_in_timeout);
        //     }
        //
        //     this.schedule_close_on_activity ();
        // }

        // private void fade_out ()
        // {
        //     this.get_style_context ().add_class ("hidden");
        //     this.pass_through = true;
        //
        //     this.close_on_activity = false;
        //     this.unschedule_close_on_activity ();
        //
        //     if (this.fade_out_timeout_id == 0) {
        //         this.fade_out_timeout_id = GLib.Timeout.add (FADE_OUT_TIME,
        //                                                      this.on_fade_out_timeout);
        //     }
        // }

        // private uint32 get_idle_time (uint32 timestamp)
        // {
        //     return this.last_event_time != 0
        //             ? timestamp - this.last_event_time
        //             : 0;
        // }

        /*
        public override bool event (Gdk.Event event)
        {
            if (!this.close_on_activity) {
                return base.event (event);
            }

            var event_time = event.get_time ();
            var idle_time  = this.get_idle_time (event_time);

            switch (event.type)
            {
                case Gdk.EventType.MOTION_NOTIFY:
                    if (event.motion.is_hint == 1) {
                        return true;
                    }

                    var dx       = this.last_motion_x >= 0.0 ? event.motion.x_root - this.last_motion_x : 0.0;
                    var dy       = this.last_motion_y >= 0.0 ? event.motion.y_root - this.last_motion_y : 0.0;
                    var distance = dx * dx + dy * dy;

                    this.last_motion_x   = event.motion.x_root;
                    this.last_motion_y   = event.motion.y_root;
                    this.last_event_time = event_time;

                    if (distance > MOTION_DISTANCE_TO_CLOSE * MOTION_DISTANCE_TO_CLOSE) {
                        this.close ();
                    }

                    break;

                case Gdk.EventType.BUTTON_PRESS:
                case Gdk.EventType.KEY_PRESS:
                case Gdk.EventType.TOUCH_BEGIN:
                    this.last_event_time = event_time;

                    if (idle_time > IDLE_TIME_TO_CLOSE) {
                        this.close ();
                    }

                    break;

                case Gdk.EventType.FOCUS_CHANGE:
                    this.last_event_time = event_time;

                    this.close ();

                    break;

                default:
                    break;
            }

            return true;
        }
        */

        [GtkCallback]
        private bool on_key_pressed (Gtk.EventControllerKey event_controller,
                                     uint                   keyval,
                                     uint                   keycode,
                                     Gdk.ModifierType       state)
        {
            return false;  // return true if keypress was handled
        }

        [GtkCallback]
        private void on_motion (Gtk.EventControllerMotion event_controller,
                                double                    x,
                                double                    y)
        {
        }

        [GtkCallback]
        private void on_focus_leave (Gtk.EventControllerFocus event_controller)
        {
        }

        // private bool on_close_on_activity_timeout ()
        // {
        //     this.close_on_activity_id = 0;
        //
        //     this.close_on_activity = true;
        //
        //     return GLib.Source.REMOVE;
        // }

        private void unschedule_close_on_activity ()
        {
            if (this.close_on_activity_id != 0) {
                GLib.Source.remove (this.close_on_activity_id);
                this.close_on_activity_id = 0;
            }
        }

        // private void schedule_close_on_activity ()
        // {
        //     this.unschedule_close_on_activity ();
        //
        //     this.close_on_activity_id = GLib.Timeout.add (MIN_DISPLAY_TIME,
        //                                                   this.on_close_on_activity_timeout);
        // }
    }
}
