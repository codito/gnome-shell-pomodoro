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


    public enum TimeBlockStatus
    {
        UNSCHEDULED,
        SCHEDULED,
        IN_PROGRESS,
        COMPLETED,
        UNCOMPLETED;

        public string to_string ()
        {
            switch (this)
            {
                case UNSCHEDULED:
                    return "unscheduled";

                case SCHEDULED:
                    return "scheduled";

                case IN_PROGRESS:
                    return "in-progress";

                case COMPLETED:
                    return "completed";

                case UNCOMPLETED:
                    return "uncompleted";

                default:
                    return "";
            }
        }
    }


    public struct TimeBlockMeta
    {
        public Pomodoro.TimeBlockStatus status;
        public uint                     cycle;
        public int64                    intended_duration;
        public bool                     is_long_break;
    }


    /**
     * Pomodoro.Session class.
     *
     * By "session" in this project we mean mostly a streak of pomodoros. Sessions are separated
     * either by a long break or inactivity.
     *
     * Class serves as a container. It merely defines the session and helps in modifying it.
     * See `SessionManager` for more high-level logic.
     */
    public class Session : GLib.Object
    {
        /**
         * A child is a wrapper over a time-block.
         *
         * Extra data is session-specific and considered private. If any of the fields needs to be public,
         * they should be moved to `TimeBlock`.
         */
        protected class Child
        {
            public Pomodoro.TimeBlock       time_block;
            public Pomodoro.TimeBlockStatus status;
            public uint                     cycle;
            public int64                    intended_duration;
            public bool                     is_long_break;
            public ulong                    changed_id;

            public Child (Pomodoro.TimeBlock time_block)
            {
                this.time_block = time_block;
                this.status = Pomodoro.TimeBlockStatus.UNSCHEDULED;
                this.cycle = 0;
                this.intended_duration = time_block.duration;
                this.is_long_break;
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
        // TODO: cache value?
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
         * Create session with predefined time-blocks.
         */
        public Session.from_template (Pomodoro.SessionTemplate template,
                                      int64                    timestamp = -1)
        {
            this.populate (template, timestamp);
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

            child.status = Pomodoro.TimeBlockStatus.SCHEDULED;

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
         * Return whether session has been finished.
         */
        public bool is_finished ()
        {
            unowned GLib.List<Child> last_link = this.children.last ();

            if (last_link != null) {
                return false;
            }

            return last_link.data.status == Pomodoro.TimeBlockStatus.COMPLETED ||
                   last_link.data.status == Pomodoro.TimeBlockStatus.UNCOMPLETED;
        }

        /**
         * Remove all scheduled time-blocks, prevent session from further rescheduling.
         *
         * You should explicitly mark time blocks as ended before using `finish()`.
         */
        public void finish (int64 timestamp = -1)
        {
            unowned GLib.List<Child> link = this.children.first ();
            unowned GLib.List<Child> tmp;

            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            while (link != null)
            {
                if (link.data.status == Pomodoro.TimeBlockStatus.UNSCHEDULED ||
                    link.data.status == Pomodoro.TimeBlockStatus.SCHEDULED)
                {
                    tmp = link.next;
                    this.remove_link (link);
                    link = tmp;
                    continue;
                }

                if (link.data.status == Pomodoro.TimeBlockStatus.IN_PROGRESS)
                {
                    GLib.warning ("Finishing a session with a time block still in progress.");

                    // TODO?
                    // var completed = link.data.time_block.is_completed (
                    //     false,
                    //     Pomodoro.Strictness.get_default (),
                    //     timestamp
                    // );
                    // this.mark_time_block_ended (link.data.time_block, completed, timestamp);

                    link.data.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;
                }

                link = link.next;
            }

            // this.remove_after (time_block);
            // this.mark_current_time_block_ended (has_timer_finished, timestamp);

            this.thaw_changed ();
        }

        /**
         * Estimate energy left.
         *
         * Pomodoros deplete energy, while breaks recover it. The starting point is energy=1.0,
         * it depletes to 0.0 JUST before a long break. A long break fully restores energy. If you keep skipping breaks
         * you may end up with negative value, leading to have a long break sooner.
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

        private void append_child (Child child)
        {
            var is_first = this.children.is_empty ();

            this.children.append (child);
            this._end_time = child.time_block.end_time;

            if (is_first) {
                this._start_time = child.time_block.start_time;
            }

            this.handle_child_added (child);
        }

        /**
         * Add the time-block and align it with the last block.
         */
        public void append (Pomodoro.TimeBlock time_block)
        {
            // TODO: convert current last long-break into a short one if needed

            if (this.contains (time_block)) {
                // TODO: warn block already belong to session
                return;
            }

            var old_start_time = this._start_time;
            var old_end_time = this._end_time;
            var old_duration = this._end_time - this._start_time;

            var last_time_block = this.get_last_time_block ();
            if (last_time_block != null) {
                time_block.set_time_range (
                    last_time_block.end_time,
                    Pomodoro.Timestamp.add (last_time_block.end_time, time_block.duration)
                );

                // time_block.move_to (this._end_time);
            }

            // TODO: mark time-block as added manually? so that it doesn't conform to template?
            this.append_child (new Child (time_block));

            if (this._start_time != old_start_time) {
                this.notify_property ("start-time");
            }

            if (this._end_time != old_end_time) {
                this.notify_property ("end-time");
            }

            if (this._end_time - this._start_time != old_duration) {
                this.notify_property ("duration");
            }
        }


        public void insert_sorted (Pomodoro.TimeBlock time_block)
        {
            // TODO
            assert_not_reached ();
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
         * Set status for the time block and ensure previous time blocks are marked as completed/uncompleted.
         *
         * It's unlikely that we will need to change statuses of previous blocks.
         */
        private void set_time_block_status (Pomodoro.TimeBlock       time_block,
                                            Pomodoro.TimeBlockStatus status)
        {
            unowned GLib.List<Child> link = this.children.first ();

            if (!this.contains (time_block)) {
                return;
            }

            while (link != null)
            {
                if (link.data.time_block == time_block)
                {
                    link.data.status = status;
                    break;
                }
                else {
                    switch (link.data.status)
                    {
                        case Pomodoro.TimeBlockStatus.COMPLETED:
                        case Pomodoro.TimeBlockStatus.UNCOMPLETED:
                            break;

                        default:
                            GLib.warning ("Changing previous time-block status to UNCOMPLETED.");
                            link.data.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;
                            break;
                    }
                }

                link = link.next;
            }
        }

        /**
         * Convenience method to get status, without getting meta.
         */
        public Pomodoro.TimeBlockStatus get_time_block_status (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);

            return link != null
                ? link.data.status
                : Pomodoro.TimeBlockStatus.UNSCHEDULED;
        }

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
                status = link.data.status,
                cycle = link.data.cycle,
                intended_duration = link.data.intended_duration,
                is_long_break = link.data.is_long_break,
            };
        }

        public void mark_time_block_started (Pomodoro.TimeBlock time_block,
                                             int64              timestamp)
        {
            assert (timestamp > 0);

            unowned GLib.List<Child>? link = this.find_link_by_time_block (time_block);
            assert (link != null);

            switch (link.data.status)
            {
                case Pomodoro.TimeBlockStatus.SCHEDULED:
                    break;

                case Pomodoro.TimeBlockStatus.IN_PROGRESS:
                    GLib.warning ("Time block is already marked as started");
                    break;

                default:
                    GLib.error ("Unable to mark time block with status \"%s\" as started",
                                link.data.status.to_string ());
                    break;
            }

            this.set_time_block_status (time_block, Pomodoro.TimeBlockStatus.IN_PROGRESS);

            time_block.move_to (timestamp);
        }

        public void mark_time_block_ended (Pomodoro.TimeBlock time_block,
                                           bool               completed,
                                           int64              timestamp)
        {
            assert (timestamp > 0);
            assert (timestamp >= time_block.start_time);

            var status = completed ? Pomodoro.TimeBlockStatus.COMPLETED : Pomodoro.TimeBlockStatus.UNCOMPLETED;

            unowned GLib.List<Child>? link = this.find_link_by_time_block (time_block);
            assert (link != null);

            switch (link.data.status)
            {
                case Pomodoro.TimeBlockStatus.IN_PROGRESS:
                    break;

                case Pomodoro.TimeBlockStatus.COMPLETED:
                case Pomodoro.TimeBlockStatus.UNCOMPLETED:
                    GLib.warning ("Time block is already marked as ended");
                    break;

                default:
                    GLib.error ("Unable to mark time block with status \"%s\" as ended", link.data.status.to_string ());
                    break;
            }

            this.set_time_block_status (time_block, status);

            link.data.time_block.end_time = timestamp;
        }


        /*
         * Methods for scheduling
         */


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

        /**
         * Schedule given child
         *
         * Child will be appended to `this.children` if it hasn't been added yet
         */
        private void schedule_child (Child                    child,
                                     Pomodoro.SessionTemplate template,
                                     uint                     cycle,
                                     int64                    timestamp = -1)
                                     requires (child.status == Pomodoro.TimeBlockStatus.UNSCHEDULED ||
                                               child.status == Pomodoro.TimeBlockStatus.SCHEDULED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var time_block = child.time_block;
            var start_time = time_block.start_time;
            var duration = time_block.duration;
            var is_long_break = false;

            assert (time_block != null);

            unowned GLib.List<Child>? link = this.children.find (child);
            unowned GLib.List<Child>? prev_link = link != null ? link.prev : this.children.last ();

            start_time = prev_link != null
                ? int64.max (prev_link.data.time_block.end_time, timestamp)
                : timestamp;

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    duration = template.pomodoro_duration;
                    break;

                case Pomodoro.State.BREAK:
                    is_long_break = cycle + 1 >= template.cycles;
                    debug ("is_long_break = %s", is_long_break ? "yes" : "no");

                    duration = is_long_break
                        ? template.long_break_duration
                        : template.short_break_duration;
                    break;

                default:
                    break;
            }

            // TODO: Use scheduler

            child.status = Pomodoro.TimeBlockStatus.SCHEDULED;
            child.cycle = cycle;
            child.intended_duration = duration;
            child.is_long_break = is_long_break;

            time_block.set_time_range (start_time, start_time + duration);

            if (link == null) {
                this.append_child (child);
            }

            this.emit_changed ();
        }

        /**
         * Setup time-blocks according to given template.
         *
         * Only works if session is empty. Use `.reschedule()` if session is already populated.
         */
        public void populate (Pomodoro.SessionTemplate template,  // TODO: don't pass template through params
                              int64                    timestamp = -1)
        {
            if (!this.children.is_empty ())
            {
                warning ("Ignoring Session.populate(). Session is not empty.");
                return;
            }

            Pomodoro.TimeBlock? time_block;

            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();
            this._start_time = timestamp;
            this._end_time = timestamp;

            debug ("------------------ populate begin ------------------");

            for (var cycle = 0; cycle < template.cycles; cycle++)
            {
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);
            }

            debug ("------------------- populate end -------------------");

            this.thaw_changed ();
        }

        /**
         * Strict scheduling prioritises that pomodoro blocks and long break gets completed.
         *
         * It's meant to be a default behaviour, which is most predictable.
         */
        private void schedule_strict (Pomodoro.SessionTemplate template,
                                        int64                    timestamp)
        {
            unowned GLib.List<Child> link = this.children.first ();
            Pomodoro.TimeBlock?      time_block;

            var cycle = -1;  // first pomodoro will have cycle=0
            var n = 0;  // TODO remove

            while (link != null)
            {
                assert (n++ < 100);

                // Treat pomodoro as a start of a new cycle, but ignore past pomodoros that
                // were marked as uncompleted ones.
                if (link.data.time_block.state == Pomodoro.State.POMODORO &&
                    link.data.status != Pomodoro.TimeBlockStatus.UNCOMPLETED)
                {
                    cycle++;
                }

                if (link.data.status == Pomodoro.TimeBlockStatus.SCHEDULED ||
                    link.data.status == Pomodoro.TimeBlockStatus.UNSCHEDULED)
                {
                    // Drop unnecessary cycles.  // TODO: is postponing long break will drop completed children?
                    // TODO: ensure we're truncating only scheduled children
                    if (cycle + 1 > template.cycles) {
                        this.remove_links_after (link);
                        this.remove_link (link);
                        link = null;
                        cycle--;
                        break;
                    }

                    // Reschedule time-block.
                    if (link.data.status == Pomodoro.TimeBlockStatus.SCHEDULED)
                    {
                        this.schedule_child (link.data,
                                             template,
                                             int.max (cycle, 0),
                                             timestamp);
                    }
                }
                else {
                    // Do not modify completed or in-progress blocks.
                }

                link = link.next;
            }

            // Append a break in case last cycle doesn't end with one,
            // or when break hasn't been completed.
            link = this.children.last ();

            if (link != null && (
                link.data.time_block.state != Pomodoro.State.BREAK ||
                link.data.status == Pomodoro.TimeBlockStatus.UNSCHEDULED))
            {
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block),
                                     template,
                                     int.max (cycle, 0),
                                     timestamp);
            }

            // Append missing cycles.
            while (cycle + 1 < template.cycles)
            {
                cycle++;

                // this.append_cycle (template, cycle, timestamp);
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);
            }

            // Append extra cycle if long break wasn't completed.
            link = this.children.last ();

            if (link != null &&
                link.data.time_block.state == Pomodoro.State.BREAK &&
                link.data.status == Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                cycle++;

                // this.append_cycle (template, cycle, timestamp);
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);
            }
        }

        /**
         * Lenient scheduling prioritises preserving pomodoro:break ratio.
         *
         * As a side effect, it may reduce or add number of cycles, so it may not be most intuitive.
         */
        private void schedule_lenient (Pomodoro.SessionTemplate template,
                                         int64                    timestamp)
        {
            // TODO
        }

        /**
         * Scheduling will realign scheduled time-blocks. It may create new blocks according to strictness,
         * given template and time-blocks statuses.
         */
        public void schedule (Pomodoro.SessionTemplate template,
                                Pomodoro.Strictness      strictness = Pomodoro.Strictness.STRICT,
                                int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            debug ("------------------- reschedule begin -------------------");

            this.freeze_changed ();

            // this.remove_unscheduled_time_blocks ();

            switch (strictness)
            {
                case Pomodoro.Strictness.STRICT:
                    this.schedule_strict (template, timestamp);
                    break;

                case Pomodoro.Strictness.LENIENT:
                    this.schedule_lenient (template, timestamp);
                    break;

                default:
                    assert_not_reached ();
            }

            debug ("-------------------- reschedule end --------------------");

            this.thaw_changed ();
        }

        // TODO: deprecated
        public void reschedule (Pomodoro.SessionTemplate template,
                                Pomodoro.Strictness      strictness = Pomodoro.Strictness.STRICT,
                                int64                    timestamp = -1)
        {
            this.schedule (template, strictness, timestamp);
        }

        /**
         * Extend session by one cycle
         *
         * Only make changes to blocks scheduled into future.
         */
        public void extend (Pomodoro.SessionTemplate template,
                            int64                    timestamp = -1)
        {
            // var template = Pomodoro.SessionTemplate ();
            // template.cycles = 1;
            // this.populate (template, timestamp);

            // TODO append one cycle
            // TODO ensure only one long break is scheduled

            Pomodoro.TimeBlock? time_block;
            // var cycle = this.get_cycles_count ();
            var cycle = this.cycles;

            time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            this.schedule_child (new Child (time_block), template, cycle, timestamp);

            time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
            this.schedule_child (new Child (time_block), template, cycle, timestamp);
        }

        /**
         * Try to shorten the session by one cycle
         *
         * Only make changes to blocks scheduled into future.
         */
        public void shorten (int64 timestamp = -1)
        {
            // var cycles = this.get_cycles ();
            // if (cycles.is_empty ()) {
            //     return;
            // }

            // var last_cycle = cycles.last ().data;

            // TODO
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




        // TODO: this shouldn't be in Session. Move it to TimeBlock
        // public void mark_gap_started (Pomodoro.TimeBlock time_block,
        //                               int64              timestamp)
        // {
        // }

        // TODO: this shouldn't be in Session. Move it to TimeBlock
        // public void mark_gap_ended (Pomodoro.TimeBlock time_block,
        //                             int64              timestamp)
        // {
        // }

        // TODO: use this.children.find (child)
        // private unowned GLib.List<Child>? find_link_by_child (Child? child)
        // {
        //     unowned GLib.List<Child> link = this.children.first ();

        //     while (link != null)
        //     {
        //         if (link.data == child) {
        //             return link;
        //         }

        //         link = link.next;
        //     }

        //     return null;
        // }

        /*
        private void clear ()
        {
            unowned List<Child> link;

            while ((link = this.children.first ()) != null)
            {
                var child = link.data;  // TODO: transfer ownership?

                this.children.remove_link (link);
                this.handle_child_removed (child);
            }

            this.children = null;
            this._start_time = Pomodoro.Timestamp.MIN;
            this._end_time = Pomodoro.Timestamp.MAX;

            this.emit_changed ();
        }
        */


        /*
        public uint get_cycles_count ()
        {
            unowned GLib.List<Child> last_link = this.children.last ();

            return last_link != null ? last_link.data.cycle + 1 : 0;
        }
        */


        /*
        public void align_before (Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                return;
            }

            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);
            if (link == null) {
                return;
            }

            link = link.prev;

            while (link != null)
            {
                this.change_time_block (time_block, () => {
                    time_block = link.data.time_block;
                    time_block.move_by (link.next.data.time_block.start_time - time_block.end_time);
                });

                link = link.prev;
            }

            this.emit_changed ();
        }

        public void align_after (Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                return;
            }

            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);
            if (link == null) {
                return;
            }

            link = link.next;

            while (link != null)
            {
                this.change_time_block (time_block, () => {
                    time_block = link.data.time_block;
                    time_block.move_to (link.prev.data.time_block.start_time);
                });

                link = link.next;
            }

            this.emit_changed ();
        }
        */



        /**
         * A helper wrapper to differentiate between when a time-block has changed, from Session instance changes it.
         */
        // TODO: rename to freeze_time_block / thaw_time_block
        /*
        private void change_time_block (Pomodoro.TimeBlock                    time_block,
                                        GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            // if (data.changed_id > 0) {
            //     GLib.SignalHandler.block (time_block, data.changed_id);
            // }

            // if (data.notify_start_time_id > 0) {
            //     GLib.SignalHandler.block (time_block, data.notify_start_time_id);
            // }

            // if (data.notify_end_time_id > 0) {
            //     GLib.SignalHandler.block (time_block, data.notify_end_time_id);
            // }

            func (time_block);

            // if (data.changed_id > 0) {
            //     GLib.SignalHandler.unblock (time_block, data.changed_id);
            // }

            // if (data.notify_start_time_id > 0) {
            //     GLib.SignalHandler.unblock (time_block, data.notify_start_time_id);
            // }

            // if (data.notify_end_time_id > 0) {
            //     GLib.SignalHandler.unblock (time_block, data.notify_end_time_id);
            // }
        }
        */
