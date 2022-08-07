namespace Pomodoro
{
    private const int64 TIME_TO_RESET_SESSION = 3600 * 1000000;  // microseconds


    public struct SessionTemplate
    {
        public int64 pomodoro_duration;
        public int64 short_break_duration;
        public int64 long_break_duration;
        public uint  cycles;

        // public SessionTemplate ()
        // {
        //     this.pomodoro_duration = Pomodoro.Settings.get_pomodoro_duration ();
        //     this.short_break_duration = Pomodoro.Settings.get_short_break_duration ();
        //     this.long_break_duration = Pomodoro.Settings.get_long_break_duration ();
        //     this.cycles = Pomodoro.Settings.get_cycles_per_session ();
        // }

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
        protected class Child
        {
            public Pomodoro.TimeBlock time_block;
            // public uint  cycles;

            // Internal data managed by session or session manager
            // It would be cleaner if Session wrapped each time block with this extra data
            public int64 intended_duration;
            public int64 elapsed;
            public float score;
            public ulong changed_id;

            public Child (Pomodoro.TimeBlock time_block)
            {
                this.time_block = time_block;
                this.intended_duration = time_block.duration;
                this.elapsed = 0;
                this.score = 0.0f;
                this.changed_id = 0;
            }
        }

        // /**
        //  * Idle time after which session should no longer be continued, and new session should be created.
        //  */
        // public const int64 EXPIRY_TIMEOUT = Pomodoro.Interval.HOUR;

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
                var child = link.data;  // TODO: reansfer ownership?

                this.children.remove_link (link);
                this.child_removed (child);
            }

            this.children = null;
            this._start_time = Pomodoro.Timestamp.MIN;
            this._end_time = Pomodoro.Timestamp.MAX;

            // this.emit_changed ();
        }

        private unowned GLib.List<Child>? find_child (Pomodoro.TimeBlock? time_block)
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
        public void populate (Pomodoro.SessionTemplate template,
                              int64                    timestamp = -1)
        {
            if (!this.children.is_empty ())
            {
                warning ("Ignoring Session.populate(). Session is not empty.");
                return;
            }

            Pomodoro.ensure_timestamp (ref timestamp);

            var remaining_cycles = template.cycles;
            Pomodoro.TimeBlock? time_block;

            this.freeze_changed ();

            this._start_time = timestamp;
            this._end_time = timestamp;

            while (remaining_cycles > 0)
            {
                remaining_cycles--;

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                time_block.set_time_range (this._end_time, this._end_time + template.pomodoro_duration);
                this.append_internal (time_block);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                time_block.set_time_range (
                    this._end_time,
                    this._end_time + (
                        remaining_cycles != 0 ? template.short_break_duration : template.long_break_duration
                    )
                );
                this.append_internal (time_block);
            }

            // this.update_time_range ();  // it's called after every addition / removal
            this.thaw_changed ();
        }

        /**
         * Remove link and all links following
         */
        private void truncate (GLib.List<Child> link)
        {
            // unowned GLib.List<Child> link = first_link;
            // unowned GLib.List<Child> next_link = first_link;

            if (link == null) {
                return;
            }

            if (link.next != null) {
                this.truncate (link.next);
            }

            this.children.delete_link (link);
            this.child_removed (link.data);

            // while (link != null)
            // {
            //     next_link = link.next;
            //     child = link.data;
            //
            //     this.children.delete_link (link);
            //     this.child_removed (child);
            //
            //     link = next_link;
            // }
        }

        private void schedule_time_block (Pomodoro.SessionTemplate template,
                                          Pomodoro.TimeBlock       time_block,
                                          uint                     cycle,
                                          int64                    timestamp)
        {
            var new_start_time = timestamp;
            var new_duration = time_block.duration;

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    new_duration = template.pomodoro_duration;
                    break;

                case Pomodoro.State.BREAK:
                    new_duration = cycle < template.cycles
                        ? template.short_break_duration
                        : template.long_break_duration;
                    break;

                default:
                    break;
            }

            // TODO: align to calendar events

            time_block.set_time_range (new_start_time, new_start_time + new_duration);
        }

        /**
         * TODO: describe strict rescheduling
         */
        private void reschedule_strict (Pomodoro.SessionTemplate template,
                                        // Pomodoro.TimeBlock?      first_time_block,
                                        int64                    timestamp)
        {
            unowned GLib.List<Child>   link = this.children.first ();
            // unowned GLib.List<Child>   prev_link = null;
            // unowned GLib.List<Child>   next_link;
            unowned Pomodoro.TimeBlock time_block;
            Child child;

            var cycle   = 0;  // 1st cycle will have cycle=1
            // var editing = first_time_block == null;
            var editing = false;
            var is_first = true;
            // var previous_end_time = timestamp;

            while (link != null)
            {
                time_block = link.data.time_block;
                // cycle = link.data.cycle;

                // if (time_block.status == Pomodoro.TimeBlockStatus.UNSCHEDULED)
                // {
                    // if (editing) {
                        // TODO: adjust time range and change to scheduled, remove it, or ignore it?
                    //     assert_not_reached ();

                        // next_link = link.next;
                        // child = link.data;

                        // this.children.delete_link (link);
                        // this.child_removed (child);

                        // link = next_link;
                    // }

                //     continue;
                // }

                if (time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED) {
                    editing = true;
                }

                if (editing && time_block.status != Pomodoro.TimeBlockStatus.SCHEDULED) {
                    assert_not_reached ();  // TODO: can we cecover from that?
                }

                if (time_block.state == Pomodoro.State.POMODORO &&
                    time_block.status != Pomodoro.TimeBlockStatus.UNCOMPLETED)
                {
                    cycle++;

                    if (editing && cycle > template.cycles)
                    {
                         // while (link != null)
                         // {
                         //     next_link = link.next;
                         //     child = link.data;
                         //
                         //     this.children.delete_link (link);
                         //     this.child_removed (child);
                         //
                         //     link = next_link;
                         // }
                         this.truncate (link);
                         break;
                    }
                }

                if (time_block.status == Pomodoro.TimeBlockStatus.SCHEDULED)
                {
                    var time_block_start_time = link.prev != null && !is_first
                        ? int64.max (link.prev.data.time_block.end_time, timestamp)
                        : timestamp;

                    this.schedule_time_block (template,
                                              time_block,
                                              cycle,
                                              time_block_start_time);

                    link.data.intended_duration = time_block.duration;
                    is_first = false;

                    /*
                    var new_start_time = link.prev != null ? link.prev.data.time_block.end_time : time_block.start_time;
                    var new_duration = time_block.duration;

                    switch (time_block.state)
                    {
                        case Pomodoro.State.POMODORO:
                            new_duration = template.pomodoro_duration;
                            break;

                        case Pomodoro.State.BREAK:
                            new_duration = cycle < template.cycles
                                ? template.short_break_duration
                                : template.long_break_duration;
                            break;

                        default:
                            break;
                    }

                    // TODO: align to calendar events

                    link.data.intended_duration = new_duration;
                    time_block.set_time_range (new_start_time, new_start_time + new_duration);
                    */
                }
                else
                {
                    // don't modify past or ongoing blocks
                }

                link = link.next;
            }

//              // create extra cycles
//              while (cycle <= template.cycles)
//              {
//                  time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
//                  time_block.set_time_range (this._end_time, this._end_time + template.pomodoro_duration);
//                  this.append_internal (time_block);
//                  time_block.set_time_range (
//                      this._end_time,
//                      this._end_time + (
//             }

            this.emit_changed ();
        }

        /**
         * TODO: describe lenient rescheduling
         */
        private void reschedule_lenient (Pomodoro.SessionTemplate template,
                                         // Pomodoro.TimeBlock?      first_time_block,
                                         int64                    timestamp)
        {

        }

        /**
         * TODO: docstring
         */
        public void reschedule (Pomodoro.SessionTemplate template,
                                // Pomodoro.TimeBlock?      first_time_block = null,
                                Pomodoro.Strictness      strictness = Pomodoro.Strictness.STRICT,
                                int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            switch (strictness)
            {
                case Pomodoro.Strictness.STRICT:
                    this.reschedule_strict (template, timestamp);
                    // this.reschedule_strict (template, first_time_block, timestamp);
                    break;

                case Pomodoro.Strictness.LENIENT:
                    this.reschedule_lenient (template, timestamp);
                    // this.reschedule_lenient (template, first_time_block, timestamp);
                    break;

                default:
                    assert_not_reached ();
            }

            this.thaw_changed ();
        }

        /**
         * Normalization ensures that following time-blocks align with each other.
         */
        public void normalize (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            this.freeze_changed ();

            // TODO

            this.thaw_changed ();
        }

        /**
         * Extend session by one cycle
         *
         * Only make changes to blocks scheduled into future.
         */
        public void extend (int64 timestamp = -1)  // TODO: rename to add_cycle?
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

            // this.update_time_range ();
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

            unowned GLib.List<Child> link = this.find_child (time_block);
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

            // this.update_time_range ();
            this.emit_changed ();
        }

        public void align_after (Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                return;
            }

            unowned GLib.List<Child> link = this.find_child (time_block);
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

            // this.update_time_range ();
            this.emit_changed ();
        }

        /**
         * Split session into cycles.
         *
         * Cycles are determined around pomodoros. Even if user skips a break, a single pomodoro is treated as a cycle.
         */
        public GLib.List<Pomodoro.Cycle> get_cycles ()
        {
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

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            if (time_block == null) {
                return null;
            }

            unowned GLib.List<Child> link = this.find_child (time_block);
            if (link == null || link.prev == null) {
                return null;
            }

            return link.prev.data.time_block;
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            if (time_block == null) {
                return null;
            }

            unowned GLib.List<Child> link = this.find_child (time_block);
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
            unowned List<Child> link = this.find_child (time_block);

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

        private void append_internal (Pomodoro.TimeBlock time_block)
        {
            var is_first = this.children.is_empty ();
            var child    = new Child (time_block);

            this.children.append (child);
            this._end_time = time_block.end_time;

            if (is_first) {
                this._start_time = time_block.start_time;
            }

            this.child_added (child);
        }

        /**
         * Add the time-block and align it with the last block.
         */
        public void append (Pomodoro.TimeBlock time_block)
                                       // requires (time_block.session == null)
        {
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

            this.append_internal (time_block);

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
            unowned GLib.List<Child> link = this.find_child (time_block);
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
            unowned GLib.List<Child> link = this.find_child (time_block);

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
            unowned GLib.List<Child> link = this.find_child (time_block);

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

