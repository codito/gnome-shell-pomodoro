namespace Pomodoro
{
    private const int64 TIME_TO_RESET_SESSION = 3600 * 1000000;  // microseconds


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
         * Idle time after which session should no longer be continued, and new session should be created.
         */
        public const int64 EXPIRE_TIMEOUT = Pomodoro.Interval.HOUR;

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

        public int64 duration {
            get {
                return this._end_time - this._start_time;
            }
        }

        private GLib.List<Pomodoro.TimeBlock> time_blocks;
        private int64 _start_time = Pomodoro.Timestamp.MIN;
        private int64 _end_time = Pomodoro.Timestamp.MAX;
        // private int64 finished_time = Pomodoro.Timestamp.UNDEFINED;

        private int  changed_freeze_count = 0;
        private bool changed_is_pending = false;


        /**
         * Create empty session.
         */
        public Session ()
        {
        }

        /**
         * Create session with predefined time-blocks.
         */
        public Session.from_template (int64 timestamp = -1)
        {
            this.populate (timestamp);
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
         * Insert time-blocks according to settings.
         */
        private void populate (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var settings = Pomodoro.get_settings ();
            var remaining_pomodoros = settings.get_uint ("pomodoros-per-session");

            this._start_time = timestamp;
            this._end_time = timestamp;

            while (remaining_pomodoros > 0)
            {
                this.append_internal (
                    new Pomodoro.TimeBlock.with_start_time (Pomodoro.State.POMODORO, this._end_time)
                );
                remaining_pomodoros--;

                if (remaining_pomodoros > 0) {
                    this.append_internal (
                        new Pomodoro.TimeBlock.with_start_time (Pomodoro.State.BREAK, this._end_time)
                    );
                }
                else {
                    var time_block = new Pomodoro.TimeBlock.with_start_time (Pomodoro.State.BREAK, this._end_time);
                    time_block.end_time = time_block.start_time + Pomodoro.State.get_long_break_duration ();
                    this.append_internal (time_block);
                    break;
                }
            }
        }

        public void extend (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            // TODO
            //  - append pomodoro block
            //  - append a long break block
            //  - change duration of scheduled long break, make it shorter
            // (only make changes for blocks scheduled into future)
        }

        public void shorten (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            // TODO:
            //  - remove last break block
            //  - remove pomodoro block
            //  - change duration of scheduled short break, make it longer
            // (only make changes for blocks scheduled into future)
        }

        public void move_by (int64 offset)
        {
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

            while (link != null) {
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

            while (link != null) {
                time_block = link.data;
                time_block.move_to (link.prev.data.start_time);

                link = link.next;
            }
        }



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



        public bool is_expired (int64 timestamp = -1)
        {
            Pomodoro.ensure_timestamp (ref timestamp);

            var last_time_block = this.get_last_time_block ();

            return last_time_block != null && last_time_block.end_time + EXPIRE_TIMEOUT > timestamp;
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



        public unowned Pomodoro.TimeBlock? get_first_time_block ()
        {
            return this.time_blocks.nth_data (0);
        }

        public unowned Pomodoro.TimeBlock? get_last_time_block ()
        {
            unowned GLib.List<Pomodoro.TimeBlock> last_link = this.time_blocks.last ();

            return last_link != null ? last_link.data : null;
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

                // time_block.shift_to (this._end_time);
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
