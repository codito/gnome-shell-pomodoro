using GLib;


namespace Pomodoro
{
    public struct SessionTemplate
    {
        public int64 pomodoro_duration;
        public int64 short_break_duration;
        public int64 long_break_duration;
        public uint  cycles;

        public SessionTemplate ()
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
            this.cycles = settings.get_uint ("pomodoros-per-session");
        }
    }


    public struct TimeBlockMeta  // TODO: rename to TimeBlockSessionContext?
    {
        public uint  cycle;
        public int64 intended_duration;
        public bool  is_long_break;
        public bool  is_completed;
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
        /**
         * A child is a wrapper over a time-block with session-specific context.
         */
        protected class Child
        {
            public Pomodoro.TimeBlock       time_block;
            public uint                     cycle;
            public int64                    intended_duration;
            public bool                     is_long_break;
            public bool                     is_completed;
            public ulong                    changed_id;

            public Child (Pomodoro.TimeBlock time_block,
                          uint               cycle)
            {
                this.time_block = time_block;
                this.cycle = cycle;
                this.intended_duration = time_block.duration;
                this.is_long_break = false;
                this.is_completed = false;
                this.changed_id = 0;
            }
        }

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
                return this._end_time - this._start_time;
            }
        }

        /**
         * Number of cycles.
         */
        public uint cycles {
            get {
                unowned GLib.List<Child> last_link = this.children.last ();

                return last_link != null ? last_link.data.cycle + 1 : 0;
            }
        }

        private GLib.List<Child> children;
        private int64            _start_time = Pomodoro.Timestamp.MIN;
        private int64            _end_time = Pomodoro.Timestamp.MAX;
        private int64            expiry_time = Pomodoro.Timestamp.UNDEFINED;
        private int              changed_freeze_count = 0;
        private bool             changed_is_pending = false;


        /**
         * Create empty session.
         */
        public Session ()
        {
        }

        /**
         * Create session with according to given template.
         *
         * Doesn't take into account schedule.
         *
         * It's intended to be used in unit tests. In real world, session should be built by `Scheduler`.
         */
        public Session.from_template (Pomodoro.SessionTemplate template,
                                      int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            var start_time = timestamp;

            this._start_time = start_time;
            this._end_time = start_time;

            for (var cycle = 0; cycle < template.cycles; cycle++)
            {
                var has_long_break = cycle >= template.cycles - 1;

                var pomodoro_time_block = new Pomodoro.TimeBlock.with_start_time (start_time, Pomodoro.State.POMODORO);
                pomodoro_time_block.duration = template.pomodoro_duration;
                this.append_child (new Child (pomodoro_time_block, cycle));

                start_time += pomodoro_time_block.duration;

                var break_time_block = new Pomodoro.TimeBlock.with_start_time (timestamp, Pomodoro.State.BREAK);
                break_time_block.duration = has_long_break ? template.long_break_duration : template.short_break_duration;
                var break_child = new Child (break_time_block, cycle);
                break_child.is_long_break = has_long_break;
                this.append_child (break_child);

                start_time += break_time_block.duration;
            }

            this.thaw_changed ();
        }

        private void update_time_range ()
        {
            unowned Pomodoro.TimeBlock first_time_block = this.get_first_time_block ();
            unowned Pomodoro.TimeBlock last_time_block = this.get_last_time_block ();

            var old_duration = this._end_time - this._start_time;

            var start_time = first_time_block != null
                ? first_time_block.start_time
                : Pomodoro.Timestamp.MIN;

            var end_time = last_time_block != null
                ? last_time_block.end_time
                : Pomodoro.Timestamp.MAX;

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

        private void handle_child_added (Child child)
        {
            unowned Pomodoro.TimeBlock time_block = child.time_block;

            time_block.session = this;

            if (child.changed_id == 0) {
                child.changed_id = time_block.changed.connect (() => {
                    this.emit_changed ();
                });
            }

            this.emit_changed ();
        }

        private void handle_child_removed (Child child)
        {
            unowned Pomodoro.TimeBlock time_block = child.time_block;

            GLib.SignalHandler.disconnect (time_block, child.changed_id);

            child.changed_id = 0;
            time_block.session = null;

            this.emit_changed ();
        }

        private void emit_changed ()
        {
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


        /*
         * Methods for managing session as a whole
         */


        /**
         * Manually set expiry time.
         *
         * A session can't determine whether it expired on its own in some circumstances.
         * For instance it's not aware when the timer gets paused, so the responsibility of managing expiry
         * passes on to a session manager.
         */
        public void set_expiry_time (int64 value)
        {
            this.expiry_time = value;
        }

        /**
         * Check whether a session is suitable for reuse after being unused.
         */
        public bool is_expired (int64 timestamp = -1)
        {
            var original_timestamp = timestamp;

            Pomodoro.ensure_timestamp (ref timestamp);

            var result = this.expiry_time >= 0
                ? timestamp >= this.expiry_time
                : false;

            return this.expiry_time >= 0
                ? timestamp >= this.expiry_time
                : false;
        }

        /**
         * Estimate energy left.
         *
         * Pomodoros deplete energy, while breaks recover it. The starting point is energy=1.0,
         * it depletes to 0.0 JUST before a long break. A long break fully restores energy. If you keep skipping breaks
         * you may end up with negative value, leading to have a long break sooner.
         *
         * Energy value is relative to given template.
         */
        public float calculate_energy (Pomodoro.SessionTemplate session_template,
                                       int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var pomodoro_duration    = (double) session_template.pomodoro_duration;
            var short_break_duration = (double) session_template.short_break_duration;
            var long_break_duration  = (double) session_template.long_break_duration;
            var cycles               = (double) session_template.cycles;

            var pomodoro_depletion   = cycles > 1.0 ? - cycles / (cycles - 1.0) : -1.0;
            var pomodoro_slope       = pomodoro_depletion / (pomodoro_duration * cycles);
            var short_break_slope    = - pomodoro_depletion / short_break_duration * (cycles - 1.0);
            var long_break_slope     = 1.0 / long_break_duration;
            var break_slope          = (long_break_slope - short_break_slope) / (long_break_duration - short_break_duration);
            var break_offset         = short_break_slope - break_slope * short_break_duration;

            unowned GLib.List<Child> link = this.children.first ();
            var energy = 1.0;

            while (link != null)
            {
                var time_block = link.data.time_block;
                var elapsed    = time_block.calculate_elapsed (timestamp);

                switch (time_block.state)
                {
                    case Pomodoro.State.POMODORO:
                        energy += pomodoro_slope * elapsed;
                        break;

                    case Pomodoro.State.BREAK:
                        energy += (break_slope * elapsed + break_offset) * elapsed;
                        break;

                    default:
                        assert_not_reached ();
                }

                link = link.next;
            }

            return (float) energy;
        }


        /*
         * Methods for container operations
         */


        private unowned GLib.List<Child>? find_link_by_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                if (link.data.time_block == time_block) {
                    return link;
                }

                link = link.next;
            }

            return null;
        }

        /**
         * Remove links following
         */
        private void remove_link (GLib.List<Child>? link)
        {
            if (link == null) {
                return;
            }

            var child = link.data;

            this.children.delete_link (link);
            this.handle_child_removed (child);
        }

        private void remove_links_after (GLib.List<Child>? link)
        {
            if (link == null) {
                return;
            }

            if (link.next != null) {
                this.remove_links_after (link.next);
                this.remove_link (link.next);
            }
        }

        private void append_child (Child child)
        {
            this.children.append (child);

            this.handle_child_added (child);
        }

        /**
         * Add the time-block and align it with the last block.
         */
        public void append (Pomodoro.TimeBlock time_block)
        {
            if (time_block.session != null) {
                GLib.warning ("Ignoring `Session.append()`. Time block is already has defined session");
                return;
            }

            var last_time_block = this.get_last_time_block ();
            var cycle           = this.cycles;

            if (last_time_block != null) {
                // time_block.set_time_range (
                //     last_time_block.end_time,
                //     Pomodoro.Timestamp.add (last_time_block.end_time, time_block.duration)
                // );
                time_block.move_to (last_time_block.end_time);

                if (time_block.state != last_time_block.state && time_block.state == Pomodoro.State.POMODORO) {
                    cycle++;
                }
            }

            this.append_child (new Child (time_block, cycle));
        }

        public void insert_before (Pomodoro.TimeBlock time_block,
                                   Pomodoro.TimeBlock sibling)
        {
            // TODO
            assert_not_reached ();
        }

        public void insert_after (Pomodoro.TimeBlock time_block,
                                  Pomodoro.TimeBlock sibling)
        {
            // TODO
            assert_not_reached ();
        }

        public void remove (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);
            if (link == null) {
                // TODO: warn that block does not belong to session
                return;
            }

            var child = link.data;

            this.children.remove_link (link);
            this.handle_child_removed (child);
        }

        public void remove_before (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                // TODO: warn that block does not belong to session
                return;
            }

            if (link.prev == null) {
                return;
            }

            this.freeze_changed ();

            while (link.prev != null)
            {
                var prev_child = link.prev.data;

                this.children.remove_link (link.prev);
                this.handle_child_removed (prev_child);
            }

            this.thaw_changed ();
        }

        public void remove_after (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                // TODO: warn that block does not belong to session
                return;
            }

            if (link.next == null) {
                return;
            }

            this.freeze_changed ();

            while (link.next != null)
            {
                var next_child = link.next.data;

                this.children.remove_link (link.next);
                this.handle_child_removed (next_child);
            }

            this.thaw_changed ();
        }

        public unowned Pomodoro.TimeBlock? get_first_time_block ()
        {
            unowned GLib.List<Child> first_link = this.children.first ();

            return first_link != null ? first_link.data.time_block : null;
        }

        public unowned Pomodoro.TimeBlock? get_last_time_block ()
        {
            unowned GLib.List<Child> last_link = this.children.last ();

            return last_link != null ? last_link.data.time_block : null;
        }

        public unowned Pomodoro.TimeBlock? get_nth_time_block (uint index)
        {
            unowned Child child = this.children.nth_data (index);

            return child != null ? child.time_block : null;
        }

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null || link.prev == null) {
                return null;
            }

            return link.prev.data.time_block;
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null || link.next == null) {
                return null;
            }

            return link.next.data.time_block;
        }

        public int index (Pomodoro.TimeBlock time_block)
        {
            var index = -1;

            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                index++;

                if (link.data.time_block == time_block) {
                    return index;
                }

                link = link.next;
            }

            return index;
        }

        public bool contains (Pomodoro.TimeBlock time_block)
        {
            if (time_block.session != this) {
                return false;
            }

            unowned List<Child> link = this.find_link_by_time_block (time_block);

            return link != null;
        }

        public void @foreach (GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                func (link.data.time_block);

                link = link.next;
            }
        }


        /*
         * Methods for managing time-blocks status
         */


        /**
         * Expose internal data via read-only `TimeBlockMeta` struct.
         */
        public Pomodoro.TimeBlockMeta get_time_block_meta (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            if (link == null) {
                return Pomodoro.TimeBlockMeta ();
            }

            return TimeBlockMeta () {
                cycle = link.data.cycle,
                intended_duration = link.data.intended_duration,
                is_long_break = link.data.is_long_break,
                is_completed = link.data.is_completed,
            };
        }

        public void move_by (int64 offset)
        {
            this.freeze_changed ();

            this.children.@foreach ((child) => {
                child.time_block.move_by (offset);
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
            unowned GLib.List<Child> link = this.children.first ();

            if (link != null) {
                this.move_by (Pomodoro.Timestamp.subtract (timestamp, link.data.time_block.start_time));
            }
        }


        /*
         * Signals
         */


        [Signal (run = "first")]
        public signal void changed ()
        {
            assert (this.changed_freeze_count == 0);  // TODO: remove

            this.update_time_range ();
        }
    }
}
