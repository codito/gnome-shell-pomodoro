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
        // /**
        //  * Idle time after which session should no longer be continued, and new session should be created.
        //  */
        // public const int64 EXPIRE_TIMEOUT = Pomodoro.Interval.HOUR;

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

        // /**
        //  * Number of cycles within a session.
        //  *
        //  * By a "cycle" we refer to a pair of Pomodoro and a Break. If a session starts with a break a cycle
        //  * starts with a break.
        //  */
        // public GLib.List<Pomodoro.Cycle> cycles {
        //     get {
        //         if (this._cycles == null) {
                    // TODO: should be done when modifying time blocks
        //             this.update_cycles ();
        //         }

        //         return this._cycles;

                // if (this._cycles)
                // {
                //     var cycles = 0U;
                //     var first_state = Pomodoro.State.UNDEFINED;
                //     unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

                //     if (link != null)
                //     {
                //         first_state = link.data.state;
                //         cycles++;
                //     }

                //     while (link != null)
                //     {
                //         if (link.prev != null &&
                //             link.data.state != link.prev.data.state &&
                //             link.data.state == first_state)
                //         {
                //             cycles++;
                //         }

                //         link = link.next;
                //     }

                //     this._cycles = (int) cycles;
                // }

                // return (uint) this._cycles;
        //     }
        // }

        private GLib.List<Pomodoro.TimeBlock> time_blocks;
        private int64                         _start_time = Pomodoro.Timestamp.MIN;
        private int64                         _end_time = Pomodoro.Timestamp.MAX;
        private int64                         expiry_time = Pomodoro.Timestamp.UNDEFINED;
        // private GLib.List<Pomodoro.Cycle>     _cycles = null;
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
            unowned List<Pomodoro.TimeBlock> link;

            while ((link = this.time_blocks.first ()) != null)
            {
                this.time_blocks.remove_link (link);
            }

            this.time_blocks = null;
            this._start_time = Pomodoro.Timestamp.MIN;
            this._end_time = Pomodoro.Timestamp.MAX;
        }

        /**
         * Apply updated template to ongoing session.
         *
         * Only scheduled timeblocks should be adjusted to a new template.
         */
        private void repopulate (Pomodoro.SessionTemplate template,
                                 int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            unowned GLib.List<Pomodoro.TimeBlock> next_link;
            Pomodoro.TimeBlock? time_block;
            var cycle = 0;

            while (link != null)
            {
                time_block = link.data;

                if (time_block.state == Pomodoro.State.POMODORO && !time_block.skipped)
                {
                    cycle++;

                    if (cycle > template.cycles) {
                        while (link != null) {
                            next_link = link.next;
                            this.time_blocks.delete_link (link);
                            link = next_link;
                        }
                        break;
                    }
                }

                if (time_block.has_started (timestamp))
                {
                    // don't modify past or ongoing blocks
                }
                else
                {
                    // modify scheduled time blocks
                    var new_start_time = link.prev != null ? link.prev.data.end_time : time_block.start_time;
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

                    time_block.set_time_range (new_start_time, new_start_time + new_duration);
                }

                link = link.next;

                if (link == null) {
                    this._end_time = time_block.end_time;
                    break;
                }
            }

            // create tailing time blocks
            while (cycle <= template.cycles)
            {
                time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                time_block.set_time_range (this._end_time, this._end_time + template.pomodoro_duration);
                this.append_internal (time_block);

                time_block = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                time_block.set_time_range (
                    this._end_time,
                    this._end_time + (
                        cycle < template.cycles ? template.short_break_duration : template.long_break_duration
                    )
                );
                this.append_internal (time_block);

                cycle++;
            }
        }

        /**
         * Setup time-blocks according to given template.
         *
         * If called again to repopulate, it will try to respect number of cycles in the template.
         * Only blocks scheduled for future will be modified.
         */
        public void populate (Pomodoro.SessionTemplate template,
                              int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            if (!this.time_blocks.is_empty ()) {
                this.repopulate (template, timestamp);
                return;
            }

            var remaining_cycles = template.cycles;
            Pomodoro.TimeBlock? time_block;

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
        }

/*
        public void populate (Pomodoro.SessionTemplate template,
                              int64                    timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var remaining_cycles = template.cycles;
            // var remaining_cycles = Pomodoro.Settings.get_cycles_per_session ();
            // var pomodoro_duration = Pomodoro.Settings.get_pomodoro_duration ();
            // var short_break_duration = Pomodoro.Settings.get_short_break_duration ();
            // var long_break_duration = Pomodoro.Settings.get_long_break_duration ();

            this._start_time = timestamp;
            this._end_time = timestamp;

            while (remaining_cycles > 0)
            {
                remaining_cycles--;

                var pomodoro = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
                pomodoro.set_time_range (this._end_time, this._end_time + template.pomodoro_duration);
                this.append_internal (pomodoro);

                if (remaining_cycles != 0) {
                    var short_break = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                    short_break.set_time_range (this._end_time, this._end_time + template.short_break_duration);
                    this.append_internal (short_break);
                }
                else {
                    var long_break = new Pomodoro.TimeBlock (Pomodoro.State.BREAK);
                    long_break.set_time_range (this._end_time, this._end_time + template.long_break_duration);
                    this.append_internal (long_break);
                }
            }
        }
        */

        /**
         * Extend session by one cycle
         *
         * Only make changes to blocks scheduled into future.
         */
        public void extend (int64 timestamp = -1)
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
        public void shorten (int64 timestamp = -1)
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
            // TODO: freeze updated signal

            this.time_blocks.@foreach ((time_block) => {
                time_block.move_by (offset);
            });
        }

        public void move_to (int64 timestamp)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            if (link != null) {
                this.move_by (Pomodoro.Timestamp.subtract (timestamp, link.data.start_time));
            }
        }

        public void align_before (Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                return;
            }

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);
            if (link == null) {
                return;
            }

            link = link.prev;

            while (link != null)
            {
                time_block = link.data;
                time_block.move_by (link.next.data.start_time - time_block.end_time);

                link = link.prev;
            }
        }

        public void align_after (Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                return;
            }

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);
            if (link == null) {
                return;
            }

            link = link.next;

            while (link != null)
            {
                time_block = link.data;
                time_block.move_to (link.prev.data.start_time);

                link = link.next;
            }
        }

        /*
        private Pomodoro.State get_first_state ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();

            while (link != null)
            {
                if (link.data.state != Pomodoro.State.UNDEFINED) {
                    return link.data.state;
                }

                link = link.next;
            }

            return Pomodoro.State.POMODORO;
        }
        */


        /**
         * Split session into cycles.
         *
         * Cycles are determined around pomodoros. Even if user skips a break, a single pomodoro is treated as a cycle.
         */
        public GLib.List<Pomodoro.Cycle> get_cycles (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            GLib.List<Pomodoro.Cycle> cycles = new GLib.List<Pomodoro.Cycle> ();
            Pomodoro.Cycle? current_cycle = null;

            // handle first cycle
            // while (link != null && link.data.state != Pomodoro.State.POMODORO)
            // {
            //     if (current_cycle == null) {
            //         current_cycle = new Pomodoro.Cycle ();
            //         cycles.append (current_cycle);
            //     }
            //
            //     current_cycle.time_blocks.append (link.data);
            //     link = link.next;
            // }

            while (link != null)
            {
                if (link.data.state == Pomodoro.State.POMODORO && !link.data.skipped) {
                    current_cycle = null;
                }

                if (current_cycle == null) {
                    current_cycle = new Pomodoro.Cycle ();
                    cycles.append (current_cycle);
                }

                current_cycle.time_blocks.append (link.data);

                link = link.next;
            }

            // this._cycles = (owned) cycles;

            return cycles;
        }

        /*
        public GLib.List<Pomodoro.Cycle> get_cycles ()
        {
            var separator = Pomodoro.State.POMODORO;

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.first ();
            GLib.List<Pomodoro.Cycle> cycles = new GLib.List<Pomodoro.Cycle> ();
            Pomodoro.Cycle? current_cycle = null;

            // if (link != null) {
            //     separator = link.data.state;
            // }

            // handle first cycle, which can start with a BREAK or UNDEFINED
            while (link != null && link.data.state != separator)
            {
                if (current_cycle == null) {
                    current_cycle = new Pomodoro.Cycle ();
                    cycles.append (current_cycle);
                }

                current_cycle.time_blocks.append (link.data);
                link = link.next;
            }

            while (link != null)
            {
                if (current_cycle == null) {
                    current_cycle = new Pomodoro.Cycle ();
                    cycles.append (current_cycle);
                }

                current_cycle.time_blocks.append (link.data);

                if (link.prev != null &&
                    link.data.state != link.prev.data.state &&
                    link.data.state == separator)
                {
                    current_cycle = null;
                }

                link = link.next;
            }

            // this._cycles = (owned) cycles;

            return cycles;
        }
        */

        /**
         * Create a shallow copy
         */
        // public Pomodoro.Session copy ()
        // {
        //     var session = new Pomodoro.Session ();
        //     session.time_blocks = this.time_blocks.copy ();
        //
        //     session.append (time_block);
        //
        //     return session;
        // }

        // TODO
        // public void join (Pomodoro.Session other)
        // {
        //     other.move_to (this.end_time);
        //     other.time_blocks.@foreach ((time_block) => {
        //         this.time_blocks.append (time_block);
        //     });
        // }





        // public void reschedule (Pomodoro.TimeBlock time_block,
        //                         int64              start_time)
        // {
        //     var offset = start_time - time_block.start_time;
        //     var changing = false;
        //
        //     if (offset == 0) {
        //         return;
        //     }
        //
        //     this.time_blocks.@foreach ((scheduled_time_block) => {
        //         if (scheduled_time_block == time_block) {
        //             changing = true;
        //         }
        //
        //         if (changing) {
        //             scheduled_time_block.move_by (offset);
        //         }
        //     });
        // }

        public void set_expiry_time (int64 timestamp = -1)
        {
            debug ("Session.set_expiry(%lld) %lld", timestamp, Pomodoro.Timestamp.from_now ());

            // Pomodoro.ensure_timestamp (ref timestamp);

            this.expiry_time = timestamp;
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
            debug ("Session.is_expired(%lld) = %s", original_timestamp, result ? "true" : "false");

            return this.expiry_time >= 0
                ? timestamp >= this.expiry_time
                : false;
        }

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
            return this.time_blocks.nth_data (0);
        }

        public unowned Pomodoro.TimeBlock? get_last_time_block ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> last_link = this.time_blocks.last ();

            return last_link != null ? last_link.data : null;
        }

        public unowned Pomodoro.TimeBlock? get_nth_time_block (uint index)
        {
            return this.time_blocks.nth_data (index);
        }

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            if (time_block == null) {
                return null;
            }

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);
            if (link == null || link.prev == null) {
                return null;
            }

            return link.prev.data;
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            if (time_block == null) {
                return null;
            }

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

        private bool contains (Pomodoro.TimeBlock time_block)
        {
            unowned List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            return link != null;
        }

        public void @foreach (GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            this.time_blocks.@foreach (func);
        }

        /*
         * Methods for editing time-blocks
         */

        private void append_internal (Pomodoro.TimeBlock time_block)
        {
            var is_first = this.time_blocks.is_empty ();

            this.time_blocks.append (time_block);
            time_block.session = this;

            this._end_time = time_block.end_time;

            if (is_first) {
                this._start_time = time_block.start_time;
            }

            this.time_block_added (time_block);
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
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);
            if (link == null) {
                // TODO: warn that block does not belong to session
                return;
            }

            this.time_blocks.remove_link (link);

            time_block.session = null;

            this.time_block_removed (time_block);
        }

        public void remove_before (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link == null) {
                return;
            }

            while (link.prev != null) {
                this.time_blocks.remove_link (link.prev);
            }
        }

        public void remove_after (Pomodoro.TimeBlock time_block)
        {
            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);

            if (link == null) {
                return;
            }

            while (link.next != null) {
                this.time_blocks.remove_link (link.next);
            }
        }





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











        // private void on_time_block_added (Pomodoro.TimeBlock time_block)
        // {
        // }

        // private void on_time_block_removed (Pomodoro.TimeBlock time_block)
        // {
        // }

        private void on_time_block_changed (Pomodoro.TimeBlock time_block)
        {
        }

        private void on_time_block_notify_start_time (Pomodoro.TimeBlock time_block)
        {
            // TODO: sort time_blocks

            unowned TimeBlock first_time_block = this.get_first_time_block ();

            this._start_time = first_time_block.start_time;
        }

        private void on_time_block_notify_end_time (Pomodoro.TimeBlock time_block)
        {
            // TODO: sort time_blocks

            unowned TimeBlock last_time_block = this.get_first_time_block ();

            this._end_time = last_time_block.end_time;
        }





        public signal void time_block_added (Pomodoro.TimeBlock time_block)
        {
            // TODO: connect time_block
            // time_block.changed.connect (this.on_time_block_changed);

            // var start_time = int64.min (this._start_time, time_block.start_time);
            // var end_time = int64.max (this._end_time, time_block.end_time);

            // if (this._start_time != start_time) {
            //     this._start_time = start_time;
            //     this.notify_property ("start-time");
                // changed = true;
            // }

            // if (this._end_time != end_time) {
            //     this._end_time = end_time;
            //     this.notify_property ("end-time");
                // changed = true;
            // }

            // if (changed) {
            //     this.changed ();
            // }
        }

        public signal void time_block_removed (Pomodoro.TimeBlock time_block)
        {
            // unowned TimeBlock first_time_block = this.get_first_time_block ();
            // unowned TimeBlock last_time_block = this.get_last_time_block ();

            // this._start_time = first_time_block != null
            //     ? first_time_block.start_time
            //     : Pomodoro.Timestamp.MIN;

            // this._end_time = last_time_block != null
            //     ? last_time_block.start_time
            //     : Pomodoro.Timestamp.MAX;
        }

        public signal void changed ();
    }
}
