namespace Pomodoro
{
    public class TimerLevelBar : Gtk.Widget
    {
        private const float LINE_WIDTH = 6.0f;
        private const float OUTLINE_ALPHA = 0.2f;  // TODO: fetch this from CSS

        private Pomodoro.Timer timer;
        private uint           timeout_id = 0;
        private int64          base_timestamp = 0;
        private double         progress = 0.0;
        // private double         max_value = 0.0;
        // private double         pomodoro_count_limit = 0.0;

        construct
        {
            // this.max_value = Pomodoro.get_settings ()
            //                           .get_child ("preferences")
            //                           .get_double ("long-break-interval");  //

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
            var progress = this.timer.score;

            if (this.progress != progress)
            {
                this.progress = progress;

                this.queue_draw ();
            }

            return GLib.Source.CONTINUE;
        }

        private uint calculate_timeout_interval ()
        {
            var width = (double) this.get_width ();
            var pomodoro_duration = 25.0 * 60.0 * (double) USEC_PER_SEC;  // TODO: get from settings
            var pomodoro_count_limit = (double) 4.0;  // TODO: get from settings

            return (uint) Math.ceil (250.0 * pomodoro_duration * pomodoro_count_limit / width);
        }

        private void start_updating ()
        {
            if (this.timeout_id == 0) {
                var interval = uint.max (this.calculate_timeout_interval (), 50);

                this.sync_time ();

                this.timeout_id = GLib.Timeout.add (interval, this.update, GLib.Priority.DEFAULT);
                GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.SessionProgressBar.update");
            }
        }

        private void stop_updating ()
        {
            if (this.timeout_id != 0) {
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

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                minimum = 100;
                natural = 200;  // TODO
                minimum_baseline = -1;
                natural_baseline = -1;
            }
            else {
                minimum = (int) LINE_WIDTH;
                natural = minimum;
                minimum_baseline = natural / 2;
                natural_baseline = minimum_baseline;
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var width         = (float) this.get_width ();
            var height        = (float) this.get_height ();
            var style_context = this.get_style_context ();
            var color         = style_context.get_color ();
            var bounds        = Graphene.Rect ();
            bounds.init (0, 0, width, height);

            var baseline = height / 2.0f;
            var padding = LINE_WIDTH / 2.0f;
            var spacing = 8.0f + 2.0f * padding;
            var block_width = (width - 2.0f * padding - 3.0 * spacing) / 4.0f;

            var context = snapshot.append_cairo (bounds);
            context.set_line_width (LINE_WIDTH);
            context.set_line_cap (Cairo.LineCap.ROUND);
            context.set_source_rgba (color.red,
                                     color.green,
                                     color.blue,
                                     color.alpha * OUTLINE_ALPHA);

            context.save ();
            context.translate (padding, baseline);

            for (var index = 0; index < 4; index++) {
                context.move_to (0.0, 0.0);
                context.line_to (block_width, 0.0);
                context.translate (block_width + spacing, 0.0);
            }

            context.stroke ();
            context.restore ();
            context.set_source_rgba (color.red,
                                     color.green,
                                     color.blue,
                                     color.alpha);
            context.translate (padding, baseline);

            for (var index = 0; index < 3; index++) {
                context.move_to (0.0, 0.0);
                context.line_to (block_width, 0.0);
                context.translate (block_width + spacing, 0.0);
            }

            context.stroke ();
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
