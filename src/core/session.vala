using GLib;


namespace Pomodoro
{
    public struct SessionTemplate
    {
        public int64 pomodoro_duration;
        public int64 short_break_duration;
        public int64 long_break_duration;
        public uint  cycles;

        public SessionTemplate.with_defaults ()
        {
            var settings = Pomodoro.get_settings ();

            this.pomodoro_duration = Pomodoro.Timestamp.from_seconds_uint (
                settings.get_uint ("pomodoro-duration")
            );
            this.short_break_duration = Pomodoro.Timestamp.from_seconds_uint (
                settings.get_uint ("short-break-duration")
            );
            this.long_break_duration = Pomodoro.Timestamp.from_seconds_uint (
                settings.get_uint ("long-break-duration")
            );
            this.cycles = settings.get_uint ("cycles");
        }

        public bool equals (Pomodoro.SessionTemplate other)
        {
            return this.pomodoro_duration == other.pomodoro_duration &&
                   this.short_break_duration == other.short_break_duration &&
                   this.long_break_duration == other.long_break_duration &&
                   this.cycles == other.cycles;
        }

        public int64 calculate_total_duration ()
        {
            var total_duration = this.pomodoro_duration * this.cycles;

            total_duration += cycles > 1
                ? this.short_break_duration * (this.cycles - 1) + this.long_break_duration
                : this.short_break_duration;

            return total_duration;
        }

        /**
         * Calculate percentage of time allocated for breaks compared to total.
         *
         * Result is in 0 - 100 range.
         */
        public double calculate_break_percentage ()
        {
            var breaks_duration = this.cycles > 1
                ? this.short_break_duration * (this.cycles - 1) + this.long_break_duration
                : this.short_break_duration;
            var total_duration = this.pomodoro_duration * this.cycles + breaks_duration;

            var ratio = total_duration > 0
                ? 100.0 * (double) breaks_duration / (double) total_duration
                : 0.0;

            return ratio;
        }

        public bool has_uniform_breaks ()
        {
            return this.cycles == 1;
        }

        public GLib.Variant to_variant ()
        {
            var builder = new GLib.VariantBuilder (new GLib.VariantType ("a{s*}"));
            builder.add ("{sv}", "pomodoro_duration", new GLib.Variant.int64 (this.pomodoro_duration));
            builder.add ("{sv}", "short_break_duration", new GLib.Variant.int64 (this.short_break_duration));
            builder.add ("{sv}", "long_break_duration", new GLib.Variant.int64 (this.long_break_duration));
            builder.add ("{sv}", "cycles", new GLib.Variant.uint32 (this.cycles));

            return builder.end ();
        }

        /**
         * Represent template as string.
         *
         * Used in tests.
         */
        public string to_representation ()
        {
            var representation = new GLib.StringBuilder ("SessionTemplate (\n");
            representation.append (@"    pomodoro_duration = $pomodoro_duration,\n");
            representation.append (@"    short_break_duration = $short_break_duration,\n");
            representation.append (@"    long_break_duration = $long_break_duration,\n");
            representation.append (@"    cycles = $cycles\n");
            representation.append (")");

            return representation.str;
        }
    }


    /**
     * Pomodoro.Session class.
     *
     * By "session" in this project we mean mostly a streak of pomodoros interleaved with breaks.
     * Session ends with either by a long break or inactivity.
     *
     * Class acts as a container. It merely defines a group of time blocks. It can be used to represent
     * historic sessions.
     */
    public class Session : GLib.Object
    {
        public int64 start_time {
            get {
                return this._start_time;
            }
        }

        public int64 end_time {
            get {
                return this._end_time;
            }
        }

        /**
         * Duration of a session.
         *
         * It will include interruptions / gap times. For real time spent use `calculate_elapsed()`.
         */
        public int64 duration {
            get {
                return Pomodoro.Timestamp.subtract (this._end_time, this._start_time);
            }
        }

        /**
         * Manually set expiry time.
         *
         * A session can't determine whether it expired on its own in some circumstances.
         * For instance it's not aware when the timer gets paused, so the responsibility of managing expiry
         * passes on to a session manager.
         */
        [CCode (notify = false)]
        public int64 expiry_time {
            get {
                return this._expiry_time;
            }
            set {
                if (this._expiry_time == value) {
                    return;
                }

                this._expiry_time = value;

                this.notify_property ("expiry-time");
            }
        }

        /**
         * Time-blocks can me modified by scheduler.
         */
        internal GLib.List<Pomodoro.TimeBlock> time_blocks;
        internal ulong                         version = 0;
        internal Pomodoro.SessionEntry?        entry = null;

        private int64                          _start_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                          _end_time = Pomodoro.Timestamp.UNDEFINED;
        private int64                          _expiry_time = Pomodoro.Timestamp.UNDEFINED;
        private GLib.List<Pomodoro.Cycle>      cycles;
        private bool                           cycles_need_update = true;
        private int                            changed_freeze_count = 0;
        private bool                           changed_is_pending = false;


        /**
         * Create empty session.
         */
        public Session ()
        {
        }

        /**
         * Create session with according to given template.
         *
         * Does not take into account users schedule.
         *
         * It's intended to be used in unit tests. In real world, session should be built by `Scheduler`.
         */
        public Session.from_template (Pomodoro.SessionTemplate template,
                                      int64                    timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            var start_time = timestamp;

            this._start_time = start_time;
            this._end_time = start_time;

            for (var cycle = 1; cycle <= template.cycles; cycle++)
            {
                var schedule_long_break = cycle >= template.cycles;

                var pomodoro_time_block = new Pomodoro.TimeBlock.with_start_time (start_time, Pomodoro.State.POMODORO);
                pomodoro_time_block.duration = template.pomodoro_duration;
                this.time_blocks.append (pomodoro_time_block);
                this.emit_added (pomodoro_time_block);

                start_time += pomodoro_time_block.duration;

                var break_time_block = new Pomodoro.TimeBlock.with_start_time (
                    start_time,
                    schedule_long_break ? Pomodoro.State.LONG_BREAK : Pomodoro.State.SHORT_BREAK);
                break_time_block.duration = schedule_long_break ? template.long_break_duration : template.short_break_duration;
                this.time_blocks.append (break_time_block);
                this.emit_added (break_time_block);

                start_time += break_time_block.duration;
            }

            this.thaw_changed ();
        }

        private void update_time_range ()
        {
            unowned var first_time_block = this.get_first_time_block ();
            unowned var last_time_block = this.get_last_time_block ();

            var old_duration = this._end_time - this._start_time;

            var start_time = first_time_block != null
                ? first_time_block.start_time
                : Pomodoro.Timestamp.UNDEFINED;

            var end_time = last_time_block != null
                ? last_time_block.end_time
                : Pomodoro.Timestamp.UNDEFINED;

            if (this._start_time != start_time) {
                this._start_time = start_time;
                this.notify_property ("start-time");
            }

            if (this._end_time != end_time) {
                this._end_time = end_time;
                this.notify_property ("end-time");
            }

            if (this._end_time - this._start_time != old_duration) {
                this.notify_property ("duration");
            }
        }

        private void invalidate_cycles ()
        {
            this.cycles_need_update = true;
        }

        private void update_cycles ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            Pomodoro.Cycle? last_cycle = null;

            this.cycles = new GLib.List<Pomodoro.Cycle> ();

            while (link != null)
            {
                if (last_cycle == null || link.data.state == Pomodoro.State.POMODORO) {
                    last_cycle = new Pomodoro.Cycle ();
                    this.cycles.append (last_cycle);
                }

                last_cycle.append (link.data);

                link = link.next;
            }

            this.cycles_need_update = false;
        }

        internal void emit_added (Pomodoro.TimeBlock time_block)
        {
            time_block.session = this;
            time_block.set_intended_duration (time_block.duration);
            time_block.changed.connect (this.on_time_block_changed);

            this.added (time_block);
        }

        internal void emit_removed (Pomodoro.TimeBlock time_block)
        {
            time_block.session = null;
            time_block.changed.disconnect (this.on_time_block_changed);

            this.removed (time_block);
        }

        private void emit_changed ()
        {
            this.version++;

            if (this.changed_freeze_count > 0) {
                this.changed_is_pending = true;
            }
            else {
                this.changed_is_pending = false;
                this.changed ();
            }
        }

        public void freeze_changed ()
        {
            this.changed_freeze_count++;
        }

        public void thaw_changed ()
        {
            this.changed_freeze_count--;

            if (this.changed_freeze_count == 0 && this.changed_is_pending) {
                this.emit_changed ();
            }
        }

        private void on_time_block_changed ()
        {
            this.emit_changed ();
        }


        /*
         * Methods for managing session as a whole
         */

        /**
         * Check whether a session is suitable for reuse after being unused.
         */
        public bool is_expired (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            return this._expiry_time >= 0
                ? timestamp >= this._expiry_time
                : false;
        }

        public bool is_scheduled ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            var first_status = link != null
                ? link.data.get_status ()
                : Pomodoro.TimeBlockStatus.SCHEDULED;

            return first_status == Pomodoro.TimeBlockStatus.SCHEDULED;
        }

        /**
         * Return whether session has a completed long break.
         *
         * The time-block must be marked with proper status; in-progress status won't do.
         */
        public bool is_completed ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                if (link.data.state == Pomodoro.State.LONG_BREAK &&
                    link.data.get_status () == Pomodoro.TimeBlockStatus.COMPLETED)
                {
                    return true;
                }

                link = link.next;
            }

            return false;
        }

        /**
         * Calculate ratio between time elapsed on breaks and total elapsed time.
         *
         * The intention here is to have a percentage how much of the time is spent on breaks.
         */
        public float calculate_break_ratio (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            int64 pomodoros_total = 0;
            int64 breaks_total = 0;

            while (link != null)
            {
                var time_block = link.data;

                switch (time_block.state)
                {
                    case Pomodoro.State.POMODORO:
                        pomodoros_total = Pomodoro.Interval.add (pomodoros_total,
                                                                 time_block.calculate_elapsed (timestamp));
                        break;

                    case Pomodoro.State.BREAK:
                    case Pomodoro.State.SHORT_BREAK:
                    case Pomodoro.State.LONG_BREAK:
                        breaks_total = Pomodoro.Interval.add (breaks_total,
                                                              time_block.calculate_elapsed (timestamp));
                        break;

                    default:
                        assert_not_reached ();
                }

                link = link.next;
            }

            var total = Pomodoro.Interval.add (pomodoros_total, breaks_total);
            var ratio = total > 0
                ? (double) breaks_total / (double) total
                : 0.0;

            return (float) ratio;
        }


        /*
         * Methods for container operations
         */


        /**
         * Remove link.
         */
        internal void remove_link (GLib.List<Pomodoro.TimeBlock>? link)
        {
            if (link == null) {
                return;
            }

            var time_block = link.data;
            link.data = null;
            this.time_blocks.delete_link (link);

            this.emit_removed (time_block);
        }

        /**
         * Remove links following.
         */
        internal void remove_links_after (GLib.List<Pomodoro.TimeBlock>? link)
        {
            if (link == null) {
                return;
            }

            if (link.next != null) {
                this.remove_links_after (link.next);
                this.remove_link (link.next);
            }
        }

        /**
         * Add the time-block and align it with the last block.
         */
        public void append (Pomodoro.TimeBlock time_block)
                            requires (time_block.session == null)
        {
            var last_time_block = this.get_last_time_block ();

            if (last_time_block != null) {
                time_block.move_to (last_time_block.end_time);
            }

            this.time_blocks.append (time_block);

            this.emit_added (time_block);
        }

        /**
         * Add the time-block as first and align it to first time-block.
         */
        public void prepend (Pomodoro.TimeBlock time_block)
                             requires (time_block.session == null)
        {
            var first_time_block = this.get_first_time_block ();

            if (first_time_block != null) {
                var new_start_time = Pomodoro.Timestamp.subtract (first_time_block.start_time,
                                                                  time_block.duration);
                time_block.move_to (new_start_time);
            }

            this.time_blocks.prepend (time_block);

            this.emit_added (time_block);
        }

        /**
         * Insert the time-block before given time-block.
         */
        public void insert_before (Pomodoro.TimeBlock time_block,
                                   Pomodoro.TimeBlock sibling)
                                   requires (time_block.session == null)
                                   requires (sibling.session == this)
        {
            unowned GLib.List<Pomodoro.TimeBlock> sibling_link = this.time_blocks.find (sibling);

            // time_block.move_to (sibling.start_time);

            this.time_blocks.insert_before (sibling_link, time_block);

            this.emit_added (time_block);
        }

        /**
         * Insert the time-block after given time-block and align it to the sibling.
         */
        public void insert_after (Pomodoro.TimeBlock time_block,
                                  Pomodoro.TimeBlock sibling)
                                  requires (time_block.session == null)
                                  requires (sibling.session == this)
        {
            unowned GLib.List<Pomodoro.TimeBlock> sibling_link = this.time_blocks.find (sibling);

            if (sibling_link.next == null) {
                this.append (time_block);
            }
            else {
                // time_block.move_to (sibling.end_time);

                this.time_blocks.insert_before (sibling_link.next, time_block);

                this.emit_added (time_block);
            }
        }

        public void remove (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link != null) {
                this.remove_link (link);
            }
            else {
                GLib.warning ("Ignoring `Session.remove()`. Time-block does not belong to the session.");
            }
        }

        public void remove_before (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link == null) {
                GLib.warning ("Ignoring `Session.remove_before()`. Time-block does not belong to the session.");
                return;
            }

            this.freeze_changed ();

            while (link.prev != null)
            {
                this.remove_link (link.prev);
            }

            this.thaw_changed ();
        }

        public void remove_after (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link == null) {
                GLib.warning ("Ignoring `Session.remove_after()`. Time-block does not belong to the session.");
                return;
            }

            this.freeze_changed ();

            while (link.next != null)
            {
                this.remove_link (link.next);
            }

            this.thaw_changed ();
        }

        public void remove_scheduled ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            unowned GLib.List<Pomodoro.TimeBlock> tmp;

            this.freeze_changed ();

            while (link != null)
            {
                if (link.data.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    tmp = link.next;
                    this.remove_link (link);
                    link = tmp;
                }
                else {
                    link = link.next;
                }
            }

            this.thaw_changed ();
        }

        public unowned Pomodoro.TimeBlock? get_first_time_block ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            return link != null ? link.data : null;
        }

        public unowned Pomodoro.TimeBlock? get_last_time_block ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.last ();

            return link != null ? link.data : null;
        }

        public unowned Pomodoro.TimeBlock? get_nth_time_block (uint index)
        {
            return this.time_blocks.nth_data (index);
        }

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link == null || link.prev == null) {
                return null;
            }

            return link.prev.data;
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link == null || link.next == null) {
                return null;
            }

            return link.next.data;
        }

        public int index (Pomodoro.TimeBlock time_block)
        {
            return this.time_blocks.index (time_block);
        }

        public bool contains (Pomodoro.TimeBlock time_block)
        {
            return this.time_blocks.index (time_block) >= 0;
        }

        public void @foreach (GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            this.time_blocks.@foreach (func);
        }

        public void move_by (int64 offset)
        {
            var logged_warnining = false;

            this.freeze_changed ();

            this.time_blocks.@foreach ((time_block) => {
                if (!logged_warnining && time_block.get_status () > Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    GLib.warning ("Moving time-blocks that have been completed.");
                    logged_warnining = true;
                }

                time_block.move_by (offset);
            });

            this.thaw_changed ();
        }

        /**
         * Move all time blocks to a given timestamp, even started / completed.
         *
         * You manually modify time blocks. Consider calling .reschedule() .
         */
        public void move_to (int64 timestamp)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            if (link != null) {
                this.move_by (Pomodoro.Timestamp.subtract (timestamp, link.data.start_time));
            }
        }


        /*
         * Methods for managing time-blocks metadata
         */


        public void set_time_block_status (Pomodoro.TimeBlock       time_block,
                                           Pomodoro.TimeBlockStatus status)
        {
            var changed = false;
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            if (!this.contains (time_block)) {
                return;
            }

            while (link != null)
            {
                var prevoious_status = link.data.get_status ();

                if (link.data == time_block)
                {
                    if (prevoious_status != status) {
                        link.data.set_status (status);
                        changed = true;
                    }
                    break;
                }

                if (prevoious_status <= Pomodoro.TimeBlockStatus.IN_PROGRESS) {
                    link.data.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);
                    changed = true;
                }

                link = link.next;
            }

            if (changed) {
                this.emit_changed ();
            }
        }

        /**
         * Cycles are not an structural part of a session, they are more like annotations. They are generated if needed
         * with `get_cycles ()`.
         */
        public GLib.List<unowned Pomodoro.Cycle> get_cycles ()
        {
            if (this.cycles_need_update) {
                this.update_cycles ();
            }

            return this.cycles.copy ();
        }

        public uint count_visible_cycles ()
        {
            if (this.cycles_need_update) {
                this.update_cycles ();
            }

            unowned GLib.List<Pomodoro.Cycle> link = this.cycles.first ();
            uint visible_cycles = 0;

            while (link != null)
            {
                if (link.data.is_visible ()) {
                    visible_cycles++;
                }

                link = link.next;
            }

            return visible_cycles;
        }

        public bool has_completed_cycle ()
        {
            unowned GLib.List<Pomodoro.Cycle> link = this.cycles.first ();

            while (link != null)
            {
                if (link.data.is_completed ()) {
                    return true;
                }

                link = link.next;
            }

            return false;
        }


        /*
         * Databaase
         */

        internal bool should_create_entry ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                if (link.data.should_create_entry ()) {
                    return true;
                }

                link = link.next;
            }

            return false;
        }

        internal bool should_update_entry ()
        {
            if (this.entry == null || this.entry.id == 0) {
                return true;
            }

            return this.entry.version != this.version;
        }

        internal Pomodoro.SessionEntry create_or_update_entry ()
        {
            if (this.entry == null) {
                this.entry = new Pomodoro.SessionEntry ();
                this.entry.repository = Pomodoro.Database.get_repository ();
            }

            this.entry.start_time = this.start_time;
            this.entry.end_time = this.end_time;
            this.entry.version = this.version;

            return this.entry;
        }

        internal void unset_entry ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                link.data.unset_entry ();
                link = link.next;
            }

            this.entry = null;
        }


        /*
         * Signals
         */

        [Signal (run = "last")]
        public signal void added (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        [Signal (run = "last")]
        public signal void removed (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        [Signal (run = "first")]
        public signal void changed ()
        {
            this.update_time_range ();
            this.invalidate_cycles ();
        }
    }
}
