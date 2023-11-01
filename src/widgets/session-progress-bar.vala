namespace Pomodoro
{
    public class SessionProgressBar : Gtk.Widget
    {
        private const uint  FADE_IN_DURATION = 500;
        private const uint  FADE_OUT_DURATION = 500;
        private const float DEFAULT_LINE_WIDTH = 6.0f;
        private const uint  MIN_TIMEOUT_INTERVAL = 50;
        private const int   MIN_WIDTH = 100;
        private const uint  VALUE_ANIMATION_DURATION = 300;
        private const uint  NORM_ANIMATION_DURATION = 700;
        private const uint  OPACITY_ANIMATION_DURATION = 500;

        /**
         * Spacing is relative the block size.
         */
        private const float SPACING_SPAN = 0.17f;


        class Block : Gtk.Widget
        {
            public Pomodoro.Timer timer {
                get {
                    return this._timer;
                }
                construct {
                    this._timer = value;
                }
            }

            public Pomodoro.Cycle cycle {
                get {
                    return this._cycle;
                }
                set {
                    if (this._cycle == value) {
                        return;
                    }

                    if (this.cycle_changed_id != 0) {
                        this._cycle.disconnect (this.cycle_changed_id);
                        this.cycle_changed_id = 0;
                    }

                    this._cycle = value;

                    if (this._cycle != null) {
                        this.cycle_changed_id = this._cycle.changed.connect (this.on_cycle_changed);
                    }

                    this.on_cycle_changed ();
                }
            }

            [CCode (notify = false)]
            public float span_start {
                get {
                    return this._span_start;
                }
                set {
                    if (this._span_start == value) {
                        return;
                    }

                    this._span_start = value;

                    this.queue_draw ();
                }
            }

            [CCode (notify = false)]
            public float span_end {
                get {
                    return this._span_end;
                }
                set {
                    if (this._span_end == value) {
                        return;
                    }

                    this._span_end = value;

                    this.queue_draw ();
                }
            }

            public double weight {
                get {
                    return this._weight;
                }
            }

            [CCode (notify = false)]
            public double backfill {
                get {
                    return this._backfill;
                }
                set {
                    if (this._backfill == value) {
                        return;
                    }

                    this._backfill = value;
                    this.backfill_set = true;

                    this.queue_draw ();
                }
            }

            [CCode (notify = false)]
            public bool backfill_set {
                get {
                    return this._backfill_set;
                }
                set {
                    if (this._backfill_set == value) {
                        return;
                    }

                    this._backfill_set = value;

                    this.update_timeout ();
                    this.queue_draw ();
                }
            }

            private Pomodoro.Cycle      _cycle;
            private Pomodoro.Timer      _timer;
            private float               _span_start = 0.0f;
            private float               _span_end = 1.0f;
            private double              _weight = 0.0;
            private double              _backfill = 0.0;
            private bool                _backfill_set = false;
            private double              last_display_value = 0.0;
            private ulong               cycle_changed_id = 0;
            private uint                timeout_id = 0;
            private uint                timeout_interval = 0;
            private Adw.TimedAnimation? value_animation;
            private double              value_animation_start_value = double.NAN;

            public Block (Pomodoro.Cycle cycle)
            {
                GLib.Object (
                    timer: Pomodoro.Timer.get_default (),
                    cycle: cycle
                );
            }

            private inline int64 get_current_time ()
            {
                return this._timer.is_running ()
                    ? this._timer.get_current_time (this.get_frame_clock ().get_frame_time ())
                    : this._timer.get_last_state_changed_time ();
            }

            public void set_span_range (float start,
                                        float end)
            {
                this._span_start = start;
                this._span_end = end;

                this.queue_draw ();
            }

            public double get_last_display_value ()
            {
                return this.last_display_value;
            }

            public float transform_value (double display_value,
                                          float  span_start = float.NAN,
                                          float  span_end = float.NAN)
            {
                if (span_start.is_nan ()) {
                    span_start = this._span_start;
                }

                if (span_end.is_nan ()) {
                    span_end = this._span_end;
                }

                return (float) Adw.lerp ((double) span_start,
                                         (double) span_end,
                                         display_value);
            }

            public double transform_position (double position)
            {
                return (position - this._span_start) / (this._span_end - this._span_start);
            }

            public double calculate_display_value ()
            {
                var timestamp = this.get_current_time ();
                var display_value = this._cycle != null ? this._cycle.calculate_progress (timestamp) : 0.0;

                if (display_value.is_nan ()) {
                    display_value = 0.0;
                }

                if (this.value_animation != null) {
                    display_value = Adw.lerp (this.value_animation_start_value,
                                              display_value,
                                              this.value_animation.value);
                }

                return display_value;
            }

            private void stop_value_animation ()
            {
                if (this.value_animation != null)
                {
                    this.value_animation.pause ();
                    this.value_animation = null;
                    this.value_animation_start_value = double.NAN;
                }
            }

            private void start_value_animation (ref double display_value)
            {
                if (this.value_animation != null) {
                    return;
                }

                var value_diff = (display_value - this.last_display_value).abs ();
                if (value_diff < 0.05) {
                    return;
                }

                var animation_duration = (uint) (Math.sqrt (value_diff) * (double) VALUE_ANIMATION_DURATION);
                var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

                this.value_animation = new Adw.TimedAnimation (this,
                                                               0.0,
                                                               1.0,
                                                               animation_duration,
                                                               animation_target);
                this.value_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                // this.value_animation.set_easing (this._timer.is_running ()
                //                                  ? Adw.Easing.EASE_IN_OUT_CUBIC
                //                                  : Adw.Easing.EASE_OUT_QUAD);
                this.value_animation.done.connect (this.stop_value_animation);
                this.value_animation.play ();
                this.value_animation_start_value = this.last_display_value;

                // Revert display_value.
                display_value = this.last_display_value;
            }

            private uint calculate_timeout_interval ()
                                                     requires (this._cycle != null)
            {
                var timestamp = this.get_current_time ();
                var width = (double) (this._span_end - this._span_start) * this.get_width ();
                var duration = (double) this._cycle.calculate_progress_duration (timestamp);

                return width > 0.0
                    ? Pomodoro.Timestamp.to_milliseconds_uint ((int64) Math.round (duration / (2.0 * width)))
                    : 0;
            }

            private void start_timeout ()
                                        requires (this._cycle != null)
                                        requires (this.get_mapped ())
            {
                var timeout_interval = this.calculate_timeout_interval ();
                timeout_interval = uint.max (timeout_interval, MIN_TIMEOUT_INTERVAL);

                if (this.timeout_interval != timeout_interval) {
                    this.timeout_interval = timeout_interval;
                    this.stop_timeout ();
                }

                if (this.timeout_id == 0 && this.timeout_interval > 0) {
                    this.timeout_id = GLib.Timeout.add (this.timeout_interval, () => {
                        this.queue_draw ();

                        return GLib.Source.CONTINUE;
                    });
                    GLib.Source.set_name_by_id (this.timeout_id, "Pomodoro.SessionProgressBar.Block.on_timeout");
                }
            }

            private void stop_timeout ()
            {
                if (this.timeout_id != 0) {
                    GLib.Source.remove (this.timeout_id);
                    this.timeout_id = 0;
                }
            }

            private void update_timeout ()
            {
                this.stop_timeout ();

                if (!this.get_mapped () || this._cycle == null || this._backfill_set) {
                    return;
                }

                var current_time_block = this._timer.user_data as Pomodoro.TimeBlock;
                if (current_time_block != null && !this._cycle.contains (current_time_block)) {
                    return;
                }

                if (this._timer.is_running ()) {
                    this.start_timeout ();
                }
            }

            public void update ()
            {
                if (this._cycle != null) {
                    this._cycle.invalidate_cache ();
                }

                this.update_timeout ();
            }

            private void on_cycle_changed ()
            {
                if (this._cycle != null) {
                    this._weight = this._cycle.get_weight ();
                }

                this.queue_draw ();
            }

            public override void map ()
            {
                // Update value to avoid animation at next redraw.
                this.last_display_value = this.calculate_display_value ();

                base.map ();

                this.update_timeout ();
            }

            public override void unmap ()
            {
                this.stop_value_animation ();
                this.stop_timeout ();

                base.unmap ();
            }

            public override void snapshot (Gtk.Snapshot snapshot)
                                           requires (!this._span_start.is_nan () && !this._span_end.is_nan ())
            {
                if (this._span_start >= 1.0f) {
                    return;
                }

                var style_context     = this.get_style_context ();
                var color             = style_context.get_color ();
                var width             = (float) this.get_width ();
                var height            = (float) this.get_height ();
                var block_x           = this._span_start * width;
                var block_width       = this._span_end.clamp (0.0f, 1.0f) * width - block_x;
                var block_bounds      = Graphene.Rect ();
                var block_outline     = Gsk.RoundedRect ();
                var display_value     = this.calculate_display_value ();

                if (this._backfill_set) {
                    display_value = (this._backfill + display_value).clamp (0.0, 1.0);
                }
                else {
                    this.start_value_animation (ref display_value);
                }

                Gdk.RGBA trough_color;
                style_context.lookup_color ("unfocused_borders", out trough_color);

                Gdk.RGBA background_color;
                style_context.lookup_color ("theme_bg_color", out background_color);

                color = blend_colors (background_color, color);

                if (this.get_direction () == Gtk.TextDirection.RTL) {
                    var transform_matrix = Graphene.Matrix ();
                    transform_matrix.init_from_2d (-1.0, 0.0, 0.0, 1.0, width, 0.0);
                    snapshot.transform_matrix (transform_matrix);
                }

                block_bounds.init (block_x,
                                   0.0f,
                                   block_width,
                                   height);
                block_outline.init_from_rect (block_bounds, 0.5f * height);

                snapshot.push_rounded_clip (block_outline);
                snapshot.append_color (display_value >= 1.0 ? color : trough_color, block_bounds);

                if (display_value > 0.0 && display_value < 1.0)
                {
                    var highlight_bounds  = Graphene.Rect ();
                    var highlight_outline = Gsk.RoundedRect ();
                    var highlight_width = block_width * (float) display_value;

                    if (highlight_width < height)
                    {
                        highlight_bounds.init (block_x + highlight_width - height,
                                               0.0f,
                                               height,
                                               height);
                        highlight_outline.init_from_rect (highlight_bounds, 0.5f * height);
                        snapshot.push_rounded_clip (highlight_outline);

                        snapshot.append_color (color, highlight_bounds);
                        snapshot.pop ();
                    }
                    else {
                        highlight_bounds.init (block_x,
                                               0.0f,
                                               highlight_width,
                                               height);
                        highlight_outline.init_from_rect (highlight_bounds, 0.5f * height);

                        snapshot.push_rounded_clip (highlight_outline);
                        snapshot.append_color (color, highlight_bounds);
                        snapshot.pop ();
                    }
                }

                snapshot.pop ();

                this.last_display_value = display_value;
            }

            public override void dispose ()
            {
                this.stop_value_animation ();
                this.stop_timeout ();

                base.dispose ();
            }
        }


        public Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            construct {
                this._timer = value;
            }
        }

        public Pomodoro.SessionManager session_manager {
            get {
                return this._session_manager;
            }
            construct {
                this._session_manager = value;
            }
        }

        [CCode (notify = false)]
        public Pomodoro.Session session {
            get {
                return this._session;
            }
            set {
                if (this._session == value) {
                    return;
                }

                this.disconnect_signals ();

                this._session = value;

                if (this.get_mapped ()) {
                    this.update ();
                    this.connect_signals ();
                }

                this.notify_property ("session");
            }
        }

        [CCode (notify = false)]
        public float line_width
        {
            get {
                return this._line_width;
            }
            set {
                if (this._line_width == value) {
                    return;
                }

                this._line_width = value;

                this.notify_property ("line-width");
                this.queue_resize ();
            }
        }

        private float                             _line_width = DEFAULT_LINE_WIDTH;
        private Pomodoro.Timer                    _timer;
        private Pomodoro.SessionManager           _session_manager;
        private Pomodoro.Session?                 _session;
        private weak Block?                       current_block;
        private double                            norm = double.NAN;
        private double                            _opacity = 1.0;
        private Adw.TimedAnimation?               norm_animation;
        private Adw.TimedAnimation?               backfill_animation;
        private Adw.TimedAnimation?               opacity_animation;
        private int64                             long_break_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                             long_break_timeout = Pomodoro.Timestamp.UNDEFINED;
        private uint                              update_idle_id = 0;
        private int                               update_freeze_count = 0;
        private ulong                             timer_tick_id = 0;
        private ulong                             session_changed_id = 0;

        static construct
        {
            set_css_name ("sessionprogressbar");
        }

        construct
        {
            this._session_manager = Pomodoro.SessionManager.get_default ();
            this._timer           = Pomodoro.Timer.get_default ();
        }

        private void remove_blocks ()
        {
            unowned Gtk.Widget? child = this.get_first_child ();

            while ((child = this.get_first_child ()) != null)
            {
                child.unparent ();
            }

            this.current_block = null;
        }

        /**
         * Remove blocks that are not in the view.
         */
        private void remove_invisible_blocks ()
                                              requires (this.norm_animation == null)
        {
            var block = (Block?) this.get_last_child ();

            while (block != null)
            {
                var prev_block = (Block?) block.get_prev_sibling ();

                if (this.current_block == block) {
                    break;
                }

                if (block.span_start >= 1.0f) {
                    block.unparent ();
                }

                block = prev_block;
            }
        }

        private double calculate_norm (double total_weight,
                                       uint   cycles_count)
        {
            return total_weight > 0.0
                ? 1.0 / (total_weight + (double) (cycles_count - 1) * (double) SPACING_SPAN)
                : 0.0;
        }

        private void update_blocks_span ()
                                         requires (!this.norm.is_nan ())
        {
            var block = (Block?) this.get_first_child ();
            var norm = this.norm_animation != null ? this.norm_animation.value : this.norm;
            var position = 0.0;
            var spacing = SPACING_SPAN * norm;

            while (block != null)
            {
                block.set_span_range ((float) position, (float) (position + block.weight * norm));
                position = block.span_end + spacing;

                block = (Block?) block.get_next_sibling ();
            }
        }

        private void stop_norm_animation ()
        {
            if (this.norm_animation != null) {
                this.norm_animation.pause ();
                this.norm_animation = null;
            }

            this.remove_invisible_blocks ();
        }

        private void start_norm_animation (double previous_norm)
        {
            if (this.norm_animation != null) {
                this.norm_animation.pause ();
                this.norm_animation = null;
            }

            if (this.get_mapped () && !previous_norm.is_nan () && !this.norm.is_nan ())
            {
                var animation_target = new Adw.CallbackAnimationTarget (this.update_blocks_span);

                this.norm_animation = new Adw.TimedAnimation (this,
                                                              previous_norm,
                                                              this.norm,
                                                              NORM_ANIMATION_DURATION,
                                                              animation_target);
                this.norm_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                this.norm_animation.done.connect (this.stop_norm_animation);
                this.norm_animation.play ();
            }
            else {
                this.remove_invisible_blocks ();
            }
        }

        private void stop_opacity_animation ()
        {
            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }
        }

        private void start_opacity_animation (double previous_opacity)
        {
            if (this.opacity_animation != null) {
                this.opacity_animation.pause ();
                this.opacity_animation = null;
            }

            if (this.get_mapped () && this._opacity != previous_opacity)
            {
                var animation_target = new Adw.CallbackAnimationTarget (this.queue_draw);

                this.opacity_animation = new Adw.TimedAnimation (this,
                                                                 previous_opacity,
                                                                 this._opacity,
                                                                 OPACITY_ANIMATION_DURATION,
                                                                 animation_target);
                this.opacity_animation.set_easing (Adw.Easing.EASE_OUT_QUAD);
                this.opacity_animation.done.connect (this.stop_opacity_animation);
                this.opacity_animation.play ();
            }
        }

        private void update_blocks_backfill (double position)
        {
            var block = (Block?) this.get_first_child ();

            while (block != null)
            {
                block.backfill = block.transform_position (position).clamp (0.0, 1.0);

                block = (Block?) block.get_next_sibling ();
            }
        }

        private void stop_backfill_animation ()
        {
            if (this.backfill_animation != null) {
                this.backfill_animation.pause ();
                this.backfill_animation = null;
            }

            var block = (Block?) this.get_first_child ();

            while (block != null) {
                block.backfill_set = false;
                block = (Block?) block.get_next_sibling ();
            }
        }

        /**
         * Setup backfill animation spanning several blocks.
         */
        private void start_backfill_animation (Block previous_block,
                                               Block current_block)
        {
            if (this.backfill_animation != null) {
                this.backfill_animation.pause ();
                this.backfill_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget (this.update_blocks_backfill);
            var position = previous_block.transform_value (previous_block.get_last_display_value ());

            if (this.get_mapped () && position > 0.0)
            {
                this.backfill_animation = new Adw.TimedAnimation (this,
                                                                  position,
                                                                  0.0,
                                                                  FADE_OUT_DURATION,
                                                                  animation_target);
                this.backfill_animation.set_easing (this._timer.is_running ()
                                                    ? Adw.Easing.EASE_IN_OUT_CUBIC
                                                    : Adw.Easing.EASE_OUT_QUAD);
                this.backfill_animation.done.connect (this.stop_backfill_animation);
                this.backfill_animation.play ();

                // Set `Block.backfill_set` early to inhibit value animation within blocks.
                this.update_blocks_backfill (position);
            }
        }

        /**
         * Synchronise blocks according to cycles.
         */
        private void update_blocks ()
        {
            if (this._session == null) {
                this._session_manager.ensure_session ();
                this._session = this._session_manager.current_session;
            }

            var cycles = this._session.get_cycles ();
            var cycles_count = 0;
            var current_cycle_index = cycles.index (this._session_manager.get_current_cycle ());
            var total_weight = 0.0;
            var previous_norm = this.norm;
            var previous_opacity = this._opacity;

            // Associate blocks with cycle. Create more blocks if needed.
            unowned GLib.List<unowned Pomodoro.Cycle> link = cycles.first ();
            unowned Block? block = (Block?) this.get_first_child ();
            unowned Block? previous_block = this.current_block;
            unowned Block? current_block = block;

            while (link != null)
            {
                var cycle = link.data;

                assert (cycle != null);

                if (link.data.is_visible ())
                {
                    if (block != null) {
                        block.cycle = cycle;
                    }
                    else {
                        var tmp = new Block (cycle);
                        tmp.insert_before (this, null);  // append child
                        block = tmp;
                    }

                    block.update ();

                    if (cycles_count <= current_cycle_index) {
                        current_block = block;
                    }

                    cycles_count++;
                    total_weight += cycle.get_weight ();
                    block = (Block?) block.get_next_sibling ();
                }

                link = link.next;
            }

            this.current_block = current_block;

            // Update blocks without associated cycles.
            while (block != null)
            {
                block.cycle = null;
                block.update ();

                block = (Block?) block.get_next_sibling ();
            }

            // Update blocks span and opacity.
            var norm = this.calculate_norm (total_weight, cycles_count);
            var opacity = norm != 1.0 ? 1.0 : 0.0;

            if (this._opacity != opacity)
            {
                this._opacity = opacity;
                this.start_opacity_animation (previous_opacity);
            }

            if (this.norm != norm)
            {
                this.norm = norm;

                if (previous_opacity > 0.0 && opacity > 0.0) {
                    this.start_norm_animation (previous_norm);
                }
            }

            if (opacity != 0.0) {
                this.update_blocks_span ();
            }

            if (this.norm_animation == null) {
                this.remove_invisible_blocks ();
            }

            // Animate value.
            if (this.backfill_animation != null)
            {
                // Let ongoing animation finish.
            }
            else if (previous_block == null ||
                     previous_block == current_block ||
                     previous_block.get_next_sibling () == current_block)
            {
                // Let the block handle value animation.
            }
            else {
                this.start_backfill_animation (previous_block, current_block);
            }
        }

        private void update_tooltip (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            if (Pomodoro.Timestamp.is_undefined (timestamp)) {
                timestamp = int64.max (this._timer.get_last_state_changed_time (),
                                       this._timer.get_last_tick_time ());
            }

            var long_break_timeout = this._timer.is_running () && Pomodoro.Timestamp.is_defined (this.long_break_time)
                ? Pomodoro.Timestamp.round (Pomodoro.Timestamp.subtract (this.long_break_time, timestamp),
                                            Pomodoro.Interval.MINUTE)
                : Pomodoro.Timestamp.UNDEFINED;

            if (this.long_break_timeout == long_break_timeout) {
                return;
            }

            if (long_break_timeout >= 0) {
                var seconds = (int) Pomodoro.Timestamp.to_seconds_uint (long_break_timeout);

                this.set_tooltip_text (_("Long break due in %s").printf (Pomodoro.format_time (seconds)));
            }
            else {
                this.set_tooltip_text (null);
            }

            this.long_break_timeout = long_break_timeout;
        }

        /**
         * Find when there will be a long break for the tooltip.
         */
        private void update_long_break_time ()
        {
            var long_break_time = Pomodoro.Timestamp.UNDEFINED;

            session.@foreach (
                (time_block) => {
                    if (time_block.state == Pomodoro.State.LONG_BREAK &&
                        time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED &&
                        Pomodoro.Timestamp.is_undefined (long_break_time))
                    {
                        long_break_time = time_block.start_time;
                    }
                }
            );

            this.long_break_time = long_break_time;
        }

        private void update ()
        {
            if (this.update_idle_id != 0) {
                GLib.Source.remove (this.update_idle_id);
                this.update_idle_id = 0;
            }

            if (this.update_freeze_count > 0) {
                return;
            }

            if (this.get_mapped ()) {
                this.update_blocks ();
                this.update_tooltip ();
            }
        }

        private void queue_update ()
        {
            if (this.update_idle_id != 0) {
                return;
            }

            this.update_idle_id = this.add_tick_callback (() => {
                this.update_idle_id = 0;
                this.update ();

                return GLib.Source.REMOVE;
            });
        }

        public void freeze_update ()
        {
            this.update_freeze_count++;

            if (this.norm_animation != null) {
                this.norm_animation.pause ();
            }

            unowned Block? block = (Block?) this.get_first_child ();

            while (block != null)
            {
                block.backfill_set = true;
                block = (Block?) block.get_next_sibling ();
            }
        }

        public void thaw_update ()
                                 ensures (this.update_freeze_count >= 0)
        {
            this.update_freeze_count--;

            unowned Block? block = (Block?) this.get_first_child ();

            while (block != null)
            {
                block.backfill_set = false;
                block = (Block?) block.get_next_sibling ();
            }

            if (this.norm_animation != null) {
                this.norm_animation.resume ();
            }

            if (this.update_freeze_count == 0) {
                this.update ();
            }
        }

        private void on_timer_tick (int64 timestamp)
        {
            this.update_tooltip (timestamp);
        }

        private void on_session_changed (Pomodoro.Session session)
        {
            this.update_long_break_time ();

            // Wait with update until next session will be available.
            this.queue_update ();
        }

        private void connect_signals ()
        {
            if (this.session_changed_id == 0 && this._session != null) {
                this.session_changed_id = this._session.changed.connect (this.on_session_changed);
            }

            if (this.timer_tick_id == 0) {
                this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);
            }
        }

        private void disconnect_signals ()
        {
            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            if (this.timer_tick_id != 0) {
                this._timer.disconnect (this.timer_tick_id);
                this.timer_tick_id = 0;
            }

            if (this.session_changed_id != 0) {
                this._session.disconnect (this.session_changed_id);
                this.session_changed_id = 0;
            }
        }

        public override void map ()
        {
            var previous_opacity = this._opacity;

            this.update_blocks ();
            this.update_tooltip ();

            base.map ();

            this.connect_signals ();

            if (previous_opacity == 0.0 && this._opacity > 0.0) {
                this.start_opacity_animation (previous_opacity);
            }
        }

        public override void unmap ()
        {
            this.disconnect_signals ();
            this.stop_backfill_animation ();
            this.stop_norm_animation ();
            this.stop_opacity_animation ();
            this.remove_blocks ();

            this.norm = double.NAN;

            base.unmap ();
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var line_width = (int) Math.ceilf (this._line_width);

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                minimum = int.max (line_width, MIN_WIDTH);
                natural = int.max (minimum, for_size);
            }
            else {
                minimum = line_width;
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        /**
         * All children have same allocation. This way animations can be a little smoother.
         */
        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var allocation = Gtk.Allocation () {
                x = 0,
                y = 0,
                width = width,
                height = height
            };
            var child = this.get_first_child ();

            while (child != null)
            {
                child.allocate_size (allocation, baseline);

                child = child.get_next_sibling ();
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var opacity = this.opacity_animation != null
                ? this.opacity_animation.value
                : this._opacity;
            var child = this.get_first_child ();

            snapshot.push_opacity (opacity);

            while (child != null)
            {
                this.snapshot_child (child, snapshot);

                child = child.get_next_sibling ();
            }

            snapshot.pop ();
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
            this.disconnect_signals ();
            this.stop_backfill_animation ();
            this.stop_norm_animation ();
            this.stop_opacity_animation ();
            this.remove_blocks ();

            this._session_manager = null;
            this._timer = null;
            this._session = null;

            base.dispose ();
        }
    }
}
