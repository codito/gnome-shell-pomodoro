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


    public class Cycle : GLib.Object
    {
        public GLib.List<unowned Pomodoro.TimeBlock> time_blocks;

        // TODO: only calculate progress for POMODORO blocks
        // public float calculate_progress (int64 timestamp = -1)
        // {
        // }
    }


    /**
     * Pomodoro.Session class.
     *
     * By "session" in this project we mean mostly a streak of pomodoros. Sessions are separated
     * either by a long break or inactivity.
     *
     * Class serves as a container. It merely defines the session and helps in modifying it.
     * For more logic look at `SessionManager`.
     */
    public class Session : GLib.Object
    {
        /**
         * A child serves as a wrapper over a time-block.
         *
         * Extra data is session specicic and considered private. If any of the fields needs to be public,
         * they should be moved to `TimeBlock` (like `status` property).
         */
        protected class Child
        {
            public Pomodoro.TimeBlock time_block;

            public uint  cycle;
            public int64 intended_duration;
            public int64 elapsed;
            public float score;
            public bool  is_long_break;
            public ulong changed_id;

            public Child (Pomodoro.TimeBlock time_block)
            {
                this.time_block = time_block;
                this.cycle = 0;
                this.intended_duration = time_block.duration;
                this.elapsed = 0;
                this.score = 0.0f;
                this.is_long_break = false;
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
         * It will include interuptions and idle times.
         */
        public int64 duration {
            get {
                return this._end_time - this._start_time;
            }
        }

        private GLib.List<Child> children;
        private int64                         _start_time = Pomodoro.Timestamp.MIN;
        private int64                         _end_time = Pomodoro.Timestamp.MAX;
        private int64                         expiry_time = Pomodoro.Timestamp.UNDEFINED;
        private int                           changed_freeze_count = 0;
        private bool                          changed_is_pending = false;

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


        /*
         * Methods for editing session as a whole
         */

        private void clear ()
        {
            unowned List<Child> link;

            while ((link = this.children.first ()) != null)
            {
                var child = link.data;  // TODO: transfer ownership?

                this.children.remove_link (link);
                this.child_removed (child);
            }

            this.children = null;
            this._start_time = Pomodoro.Timestamp.MIN;
            this._end_time = Pomodoro.Timestamp.MAX;

            this.emit_changed ();
        }

        private unowned GLib.List<Child>? find_link_by_child (Child? child)
        {
            unowned GLib.List<Child> link = this.children.first ();

            while (link != null)
            {
                if (link.data == child) {
                    return link;
                }

                link = link.next;
            }

            return null;
        }

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

        // TODO: rename to freeze_time_block / thaw_time_block
        private void change_time_block (Pomodoro.TimeBlock                    time_block,
                                        GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            debug ("change_time_block: A");

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

            for (var cycle = 0; cycle < template.cycles; cycle++)
            {
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);
            }

            this.thaw_changed ();
        }

        /**
         * Remove link and all links following
         */
        private void truncate (GLib.List<Child>? link)
        {
            if (link == null) {
                return;
            }

            if (link.next != null) {
                this.truncate (link.next);
            }

            var child = link.data;

            this.children.delete_link (link);
            this.child_removed (child);
        }

        /*
        private void mark_time_block (Pomodoro.TimeBlock       time_block,
                                      Pomodoro.TimeBlockStatus status)
        {
            unowned GLib.List<Child>   link = this.children.first ();
            unowned Pomodoro.TimeBlock time_block;

            if (!this.contains (time_block)) {
                return;
            }

            while (link != null)
            {
                if (link.data.time_block == time_block)
                {
                    link.data.time_block.status = status;
                    break;
                }
                else {
                    switch (link.data.time_block.status)
                    {
                        case Pomodoro.TimeBlockStatus.STARTED:
                            link.data.time_block.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;
                            break;

                        case Pomodoro.TimeBlockStatus.STARTED:
                            link.data.time_block.status = Pomodoro.TimeBlockStatus.UNCOMPLETED;
                            break;

                        default:
                            break;
                    }
                }

                link.data.time_block.status = new_status;
                link = link.next;
            }
        }

        public void mark_time_block_started (Pomodoro.TimeBlock time_block)
        {
            this.mark_time_block (time_block, Pomodoro.TimeBlockStatus.STARTED);
        }

        public void mark_time_block_completed (Pomodoro.TimeBlock time_block)
        {
            this.mark_time_block (time_block, Pomodoro.TimeBlockStatus.COMPLETED);
        }

        public void mark_time_block_uncompleted (Pomodoro.TimeBlock time_block)
        {
            this.mark_time_block (time_block, Pomodoro.TimeBlockStatus.UNCOMPLETED);
        }
        */
        // private void schedule_time_block (Pomodoro.TimeBlock       time_block,
        //                                   Pomodoro.SessionTemplate template,
        //                                   uint                     cycle,
        //                                   int64                    timestamp)
        //                                   requires (time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED)
        // {
        // }

        /**
         * Schedule given child
         *
         * Child will be appended to `this.children` if it hasn't been added yet
         */
        private void schedule_child (Child                    child,
                                     Pomodoro.SessionTemplate template,
                                     uint                     cycle,
                                     int64                    timestamp = -1)
                                     requires (child.time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var time_block = child.time_block;
            var start_time = time_block.start_time;
            var duration = time_block.duration;
            var is_long_break = false;

            unowned GLib.List<Child>? link = this.find_link_by_child (child);
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
                    is_long_break = (link == null || link.next == null) && cycle + 1 >= template.cycles;
                    duration = is_long_break
                        ? template.long_break_duration
                        : template.short_break_duration;
                    break;

                default:
                    break;
            }

            // TODO: align to calendar events

            child.cycle = cycle;
            child.intended_duration = duration;
            child.is_long_break = is_long_break;

            time_block.set_time_range (start_time, start_time + duration);

            if (link == null) {
                this.append_child (child);
            }

            this.emit_changed ();
        }

        /*
        private void schedule_time_block (Pomodoro.SessionTemplate template,
                                          Pomodoro.TimeBlock       time_block,
                                          uint                     cycle,
                                          int64                    timestamp)
                                          requires (time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED)
        {
            var new_start_time = timestamp;
            var new_duration = time_block.duration;
            var is_long_break = false;

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    new_duration = template.pomodoro_duration;
                    break;

                case Pomodoro.State.BREAK:
                    is_long_break = cycle >= template.cycles;
                    new_duration = is_long_break
                        ? template.long_break_duration
                        : template.short_break_duration;
                    break;

                default:
                    break;
            }

            // TODO: align to calendar events

            time_block.set_time_range (new_start_time, new_start_time + new_duration);
        }
        */

        /**
         * TODO: describe strict rescheduling
         */
        private void reschedule_strict (Pomodoro.SessionTemplate template,
                                        int64                    timestamp)
        {
            unowned GLib.List<Child> link = this.children.first ();
            Pomodoro.TimeBlock?      time_block;

            var cycle   = -1;
            var editing = false;

            while (link != null)
            {
                if (link.data.time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    editing = true;
                }

                // treat a pomodoro as a start of a new cycle, but ignore uncompleted ones
                if (link.data.time_block.state == Pomodoro.State.POMODORO &&
                    link.data.time_block.status != Pomodoro.TimeBlockStatus.UNCOMPLETED)
                {
                    cycle++;
                }

                // drop unnecesary cycles
                if (cycle + 1 > template.cycles) {
                    debug ("#A %d >= %u", cycle, template.cycles);
                    cycle--;
                    this.truncate (link);
                    // link = null;
                    break;
                }

                // reschedule time block
                if (link.data.time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED)
                {
                    this.schedule_child (link.data,
                                         template,
                                         int.max (cycle, 0),
                                         timestamp);
                }

                link = link.next;
            }

            // append a break in case last cycle don't end with one
            link = this.children.last ();

            if (link != null && link.data.time_block.state != Pomodoro.State.BREAK)
            {
                debug ("#B");
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block),
                                     template,
                                     int.max (cycle, 0),
                                     timestamp);
            }

            // append missing cycles

            while (cycle + 1 < template.cycles)
            {
                debug ("#C");
                cycle++;

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);
            }

            // add extra cycle if long break wasn't completed
            link = this.children.last ();

            if (link != null &&
                link.data.time_block.state == Pomodoro.State.BREAK &&
                link.data.time_block.status == Pomodoro.TimeBlockStatus.UNCOMPLETED)
            {
                debug ("#D");

                cycle++;

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                this.schedule_child (new Child (time_block), template, cycle, timestamp);
            }

            this.emit_changed ();
        }

        /**
         * TODO: describe lenient rescheduling
         */
        private void reschedule_lenient (Pomodoro.SessionTemplate template,
                                         int64                    timestamp)
        {

        }

        /**
         * TODO: docstring
         */
        public void reschedule (Pomodoro.SessionTemplate template,
                                Pomodoro.Strictness      strictness = Pomodoro.Strictness.STRICT,
                                int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            switch (strictness)
            {
                case Pomodoro.Strictness.STRICT:
                    this.reschedule_strict (template, timestamp);
                    break;

                case Pomodoro.Strictness.LENIENT:
                    this.reschedule_lenient (template, timestamp);
                    break;

                default:
                    assert_not_reached ();
            }

            this.thaw_changed ();
        }

        /**
         * Normalization ensures that following time-blocks align with each other.
         */
        // public void normalize (int64 timestamp = -1)
        // {
        //     Pomodoro.ensure_timestamp (ref timestamp);

        //     this.freeze_changed ();

            // TODO

        //     this.thaw_changed ();
        // }

        /**
         * Extend session by one cycle
         *
         * Only make changes to blocks scheduled into future.
         */
        public void extend (int64 timestamp = -1)  // TODO: pass template arg
        {
            var cycles = this.get_cycles ();
            var template = Pomodoro.SessionTemplate ();

            if (cycles.is_empty ()) {
                template.cycles = 1;
                this.populate (template, timestamp);
                return;
            }

            // var template = Pomodoro.SessionTemplate () {
            //     cycles = cycles.length () + 1,
            // };

            // this.populate (template, timestamp);

            // TODO
        }

        /**
         * Try to shorten the session by one cycle
         *
         * Only make changes to blocks scheduled into future.
         */
        public void shorten (int64 timestamp = -1)  // TODO: rename to remove_cycle?
        {
            var cycles = this.get_cycles ();
            if (cycles.is_empty ()) {
                return;
            }

            var last_cycle = cycles.last ().data;

            // TODO

            // var template = Pomodoro.SessionTemplate () {
            //     cycles = cycles.length () - 1,
            // };

            // this.populate (template, timestamp);
        }

        public void move_by (int64 offset)
        {
            this.children.@foreach ((child) => {
                this.change_time_block (child.time_block, () => {
                    child.time_block.move_by (offset);
                });
            });

            this.emit_changed ();
        }

        public void move_to (int64 timestamp)
        {
            unowned GLib.List<Child> link = this.children.first ();

            if (link != null) {
                this.move_by (Pomodoro.Timestamp.subtract (timestamp, link.data.time_block.start_time));
            }
        }

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

        /**
         * Split session into cycles.
         *
         * Cycles are determined around pomodoros. Even if user skips a break, a single pomodoro is treated as a cycle.
         */
        public GLib.List<Pomodoro.Cycle> get_cycles ()
        {
            // TODO: use child.cycle to diffirentiate cycles

            unowned GLib.List<Child>   link = this.children.first ();
            unowned Pomodoro.TimeBlock time_block;

            GLib.List<Pomodoro.Cycle> cycles = new GLib.List<Pomodoro.Cycle> ();
            Pomodoro.Cycle?           current_cycle = null;

            while (link != null)
            {
                time_block = link.data.time_block;

                if (time_block.state == Pomodoro.State.POMODORO &&
                    time_block.status != Pomodoro.TimeBlockStatus.UNCOMPLETED)
                {
                    current_cycle = null;
                }

                if (current_cycle == null) {
                    current_cycle = new Pomodoro.Cycle ();
                    cycles.append (current_cycle);
                }

                current_cycle.time_blocks.append (time_block);

                link = link.next;
            }

            return cycles;
        }

        /**
         * Manually set expiry time.
         *
         * A session can't determine whether it expired on its own in some circumstances.
         * For instance it's not aware when the timer gets paused, so the reponsibility of managing expiry
         * passes on to a sesssion manager.
         */
        public void set_expiry_time (int64 value)
        {
            // debug ("Session.set_expiry(%lld) %lld", timestamp, Pomodoro.Timestamp.from_now ());

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
            // debug ("Session.is_expired(%lld) = %s", original_timestamp, result ? "true" : "false");

            return this.expiry_time >= 0
                ? timestamp >= this.expiry_time
                : false;
        }

        // TODO: base expiry on TimeBlock.status

        // /**
        //  * Check whether a session is suitable for reuse after being unused.
        //  */
        // public bool is_expired (int64 timestamp = -1)
        // {
        //     Pomodoro.ensure_timestamp (ref timestamp);
        //
        //     var last_time_block = this.get_last_time_block ();  // TODO: get last unskipped time-block?
        //
        //     return last_time_block != null
        //         ? timestamp >= last_time_block.end_time + EXPIRE_TIMEOUT
        //         : false;
        // }

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

            if (this.changed_freeze_count == 0) {
                this.emit_changed ();
            }
        }






        // public int64 get_elapsed (int64 timestamp)
        // {
        // }

        // public int64 get_duration (int64 timestamp)
        // {
        // }

        // public int64 get_remaining (int64 timestamp)
        // {
        //     return this.
        // }

        // public double calculate_progress (int64 timestamp = -1)
        // {
            // TODO
        //     return 0.0;
        // }

        // private void sum_durations (out int64 pomodoros_duration,
        //                             out int64 breaks_duration)
        // {
        //     pomodoros_duration = 0;
        //     breaks_duration = 0;
        //
        //     this.time_blocks.@foreach ((time_block) => {
        //         switch (time_block.state) {
        //             case Pomodoro.State.POMDORO:
        //                 pomodoros_duration = Pomodoro.Timestamp.add (pomodoros_duration, time_block.duration);
        //                 break;
        //
        //             case Pomodoro.State.BREAK:
        //                 breaks_duration = Pomodoro.Timestamp.add (breaks_duration, time_block.duration);
        //                 break;
        //
        //             default:
        //                 break;
        //         }
        //     });
        // }

        /**
         *
         */
        public bool is_finished (int64 timestamp)
        {
            return false;  // TODO
        }

        public double calculate_pomodoro_break_ratio ()
        {
            return 0.0;  // TODO
        }

        /*
        public double calculate_pomodoro_break_ratio ()
        {
            var pomodoros_duration = 0.0;
            var breaks_duration = 0.0;

            this.time_blocks.@foreach ((time_block) => {
                switch (time_block.state) {
                    case Pomodoro.State.POMDORO:
                        pomodoros_duration += (double) time_block.duration;
                        break;

                    case Pomodoro.State.BREAK:
                        breaks_duration += (double) time_block.duration;
                        break;

                    default:
                        break;
                }
            });

            if (pomodoro_duration < 0.0) {
                return 0.0;
            }

            if (breaks_duration == 0.0) {
                return double.INFINITY;
            }

            return pomodoros_duration / breaks_duration;
        }
        */

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
            if (time_block == null) {
                return null;
            }

            unowned GLib.List<Child> link = this.find_link_by_time_block (time_block);
            if (link == null || link.prev == null) {
                return null;
            }

            return link.prev.data.time_block;
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                return null;
            }

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

        private bool contains (Pomodoro.TimeBlock time_block)
        {
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
         * Methods for editing time-blocks
         */

        private void append_child (Child child)
        {
            var is_first = this.children.is_empty ();

            this.children.append (child);
            this._end_time = child.time_block.end_time;

            if (is_first) {
                this._start_time = child.time_block.start_time;
            }

            this.child_added (child);
        }

        /*
        private void append_internal (Pomodoro.TimeBlock time_block)
        {
            var is_first = this.children.is_empty ();
            var child    = new Child (time_block);

            // TODO: these shouldnt be here
            child.intended_duration = time_block.duration;
            child.is_long_break = false;

            this.children.append (child);
            this._end_time = time_block.end_time;

            if (is_first) {
                this._start_time = time_block.start_time;
            }

            this.child_added (child);
        }*/

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

            // TODO: mark time-block as added manually? so that it doesnt conform to template?
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
            this.child_removed (child);
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
                this.child_removed (prev_child);
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
                this.child_removed (next_child);
            }

            this.thaw_changed ();
        }

        private void child_added (Child child)
        {
            unowned Pomodoro.TimeBlock time_block = child.time_block;

            time_block.session = this;
            time_block.status = Pomodoro.TimeBlockStatus.SCHEDULED;

            child.changed_id = time_block.changed.connect (() => {
                this.emit_changed ();
            });

            this.time_block_added (time_block);
        }

        private void child_removed (Child child)
        {
            unowned Pomodoro.TimeBlock time_block = child.time_block;

            GLib.SignalHandler.disconnect (time_block, child.changed_id);

            time_block.session = null;

            // if (time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED) {
            //     time_block.status = Pomodoro.TimeBlockStatus.UNSCHEDULED;
            // }

            this.time_block_removed (time_block);
        }

        [Signal (run = "first")]
        public signal void time_block_added (Pomodoro.TimeBlock time_block)  // TODO: rename to added_time_block?
        {
            this.emit_changed ();
        }

        [Signal (run = "first")]
        public signal void time_block_removed (Pomodoro.TimeBlock time_block)  // TODO: rename to removed_time_block?
        {
            this.emit_changed ();
        }

        [Signal (run = "first")]
        public signal void changed ()
        {
            this.update_time_range ();
        }
    }
}

    /*

        [Signal (run = "first")]
        public signal void time_block_added (Pomodoro.TimeBlock time_block)
        {
            // var changed_id = time_block.changed.connect (this.on_time_block_changed);
            // var notify_start_time_id = time_block.notify["start-time"].connect (this.on_time_block_notify_start_time);
            // var notify_end_time_id = time_block.notify["end-time"].connect (this.on_time_block_notify_end_time);

            var changed_id = time_block.changed.connect (() => {
                this.emit_changed ();
            });
            // var notify_start_time_id = time_block.notify["start-time"].connect (() => {
            //     this.emit_changed ();
            // });
            // var notify_end_time_id = time_block.notify["end-time"].connect (() => {
            //     this.emit_changed ();
            // });

            // TODO: we need a wrapper for time-block containing strategy data, handler ids and souch
            time_block.set_data<ulong> ("changed-id", changed_id);
            // time_block.set_data<ulong> ("notify-start-time-id", notify_start_time_id);
            // time_block.set_data<ulong> ("notify-end-time-id", notify_end_time_id);

            // this.update_time_range ();
            this.emit_changed ();
        }

        [Signal (run = "first")]
        public signal void time_block_removed (Pomodoro.TimeBlock time_block)
        {
            var changed_id = time_block.get_data<ulong> ("changed-id");
            // var notify_start_time_id = time_block.get_data<ulong> ("notify-start-time-id");
            // var notify_end_time_id = time_block.get_data<ulong> ("notify-end-time-id");

            GLib.SignalHandler.disconnect (time_block, changed_id);
            // GLib.SignalHandler.disconnect (time_block, notify_start_time_id);
            // GLib.SignalHandler.disconnect (time_block, notify_end_time_id);

            // GLib.SignalHandler.disconnect_by_func (time_block, this.on_time_block_changed, this);
            // GLib.SignalHandler.disconnect_by_func (time_block, this.on_time_block_notify_start_time, this);
            // GLib.SignalHandler.disconnect_by_func (time_block, this.on_time_block_notify_end_time, this);

            time_block.session = null;

            // this.update_time_range ();
            this.emit_changed ();
        }
     */


        // public bool has_started (int64 timestamp = -1)
        // {
        //     var first_time_block = this.get_first_time_block ();
        //
        //     if (first_time_block != null) {
        //         return first_time_block.has_started (timestamp);
        //     }
        //
        //     return false;
        // }

        // public bool has_ended (int64 timestamp = -1)
        // {
        //     var last_time_block = this.get_first_time_block ();
        //
        //     if (last_time_block != null) {
        //         return last_time_block.has_ended (timestamp);
        //     }
        //
        //     return false;
        // }

        /*
        private void on_time_block_changed (Pomodoro.TimeBlock time_block)
        {
            this.emit_changed ();
        }

        private void on_time_block_notify_start_time (GLib.ParamSpec     param_spec)
        {
            // TODO: sort time_blocks?

            // this.update_time_range ();
            this.emit_changed ();
        }

        private void on_time_block_notify_end_time (GLib.ParamSpec     param_spec)
        {
            // TODO: sort time_blocks?

            // this.update_time_range ();
            this.emit_changed ();
        }
        */

