namespace Pomodoro
{
    public class TimerProgressBar : Gtk.Widget
    {
        private const float LINE_WIDTH = 6.0f;
        private const float OUTLINE_ALPHA = 0.2f;  // TODO: fetch this from CSS

        private Pomodoro.Timer timer;
        private uint           timeout_id = 0;
        private int64          base_timestamp = 0;
        private double         position = 0.0;

        construct
        {
            var timer = Pomodoro.Timer.get_default ();

            this.timer = timer;
            // TODO: disconnect signals
            this.timer.notify["state"].connect_after (this.on_timer_state_notify);
            this.timer.notify["is-paused"].connect_after (this.on_timer_is_paused_notify);
        }

        /**
         * FrameClock uses monotonic time. Store offset for converting it to an Unix timestamp.
         */
        private void sync_time ()
        {
            // var frame_clock = this.get_frame_clock ();
            // this.base_timestamp = GLib.get_real_time () - frame_clock.get_frame_time ();

            // TODO: can this be done better?
            this.base_timestamp = GLib.get_real_time () - GLib.get_monotonic_time ();
        }

        private bool update ()
        {
            var frame_clock = this.get_frame_clock ();
            var timestamp = frame_clock.get_frame_time () + this.base_timestamp;
            var position = this.timer.state.calculate_progress (timestamp, this.timer.offset);

            if (this.position != position)
            {
                this.position = position;

                this.queue_draw ();
            }

            return GLib.Source.CONTINUE;
        }

        private uint calculate_timeout_interval ()
        {
            var width  = (double) this.get_width ();
            var height = (double) this.get_height ();
            var radius = double.min (0.5 * double.min (width, height), 150.0);
            var perimeter = 2.0 * Math.PI * radius;

            return (uint) Math.ceil (250.0 * this.timer.state_duration / perimeter);
        }

        private void start_updating ()
        {
            if (this.timeout_id == 0) {
                var interval = uint.max (this.calculate_timeout_interval (), 50);

                this.sync_time ();

                // this.update_id = this.add_tick_callback (this.update);
                this.timeout_id = GLib.Timeout.add (interval, this.update, GLib.Priority.DEFAULT);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.TimerProgressBar.update");
            }
        }

        private void stop_updating ()
        {
            if (this.timeout_id != 0) {
                // this.remove_tick_callback (this.timeout_id);
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }
        }

        private void on_timer_state_notify ()
        {
            this.stop_updating ();

            if (this.timer.is_running ()) {
                this.start_updating ();
            }

            this.update ();
        }

        private void on_timer_is_paused_notify ()
        {
            if (this.timer.is_running ()) {
                this.start_updating ();
            }
            else {
                this.stop_updating ();
            }
        }

        private void on_timer_elapsed_notify ()
        {
            // TODO: no need to

            // this.invalidate_contents ();
        }

        public override void map ()
        {
            base.map ();

            if (this.timer.is_running ()) {
                this.start_updating ();
            }

            this.update ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.stop_updating ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var width         = (float) this.get_width ();
            var height        = (float) this.get_height ();
            var style_context = this.get_style_context ();
            var color         = style_context.get_color ();

            var radius   = 0.5f * float.min (width, height);
            var center_x = 0.5f * width;
            var center_y = 0.5f * height;
            var bounds   = Graphene.Rect ();

            var outline = Gsk.RoundedRect ();  // TODO: rename to "through_bounds"
            var outline_width = LINE_WIDTH;
            var outline_color = Gdk.RGBA () {
                red=color.red,
                green=color.green,
                blue=color.blue,
                alpha=OUTLINE_ALPHA
            };
            var is_stopped = this.timer.state is Pomodoro.DisabledState;

            bounds.init (center_x - radius, center_y - radius, 2.0f * radius, 2.0f * radius);
            outline.init_from_rect (bounds, radius);

            // save/restore() is necessary so we can undo the transforms we start
            // out with.
            // snapshot.save ();

            // draw static outline
            snapshot.append_border (outline,
                                    { outline_width, outline_width, outline_width, outline_width },
                                    { outline_color, outline_color, outline_color, outline_color });

            if (!is_stopped)
            {
                var progress = this.position;
                var progress_angle_from = - 0.5 * Math.PI - 2.0 * Math.PI * progress.clamp (0.000001, 1.0);
                var progress_angle_to = - 0.5 * Math.PI;

                var context = snapshot.append_cairo (bounds);
                context.set_line_width (LINE_WIDTH);
                context.set_line_cap (Cairo.LineCap.ROUND);
                context.set_source_rgba (color.red,
                                         color.green,
                                         color.blue,
                                         color.alpha);
                context.arc_negative (center_x, center_y, radius - LINE_WIDTH / 2.0, progress_angle_from, progress_angle_to);
                context.stroke ();
            }

            // And finally, don't forget to restore the initial save() that
            // we did for the initial transformations.
            // snapshot.restore ();
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override bool focus (Gtk.DirectionType direction)
        {
            return false;
        }

        public override bool grab_focus ()
        {
            return false;
        }

        public override void dispose ()
        {
            this.stop_updating ();

            base.dispose ();
        }
    }
}
