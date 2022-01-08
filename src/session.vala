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


        /**
         * Create session without predefined time-blocks.
         */
        public Session (int64 timestamp = -1)
        {
            // var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            // time_block.start_time = timestamp;

            // this.append (time_block);
            this.populate (timestamp);
        }

        /**
         * Create session without predefined time-blocks.
         */
        public Session.empty ()
        {
            // ensure_timestamp (ref timestamp);

            // var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            // time_block.start_time = timestamp;

            // this.append (time_block);
        }

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
            ensure_timestamp (ref timestamp);

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
                        new Pomodoro.TimeBlock.with_start_time (Pomodoro.State.SHORT_BREAK, this._end_time)
                    );
                }
                else {
                    this.append_internal (
                        new Pomodoro.TimeBlock.with_start_time (Pomodoro.State.LONG_BREAK, this._end_time)
                    );
                    break;
                }
            }
        }


        /*
         * Methods for modifying ongoing session
         */

        private void extend ()
        {
        }

        private void shorten ()
        {
        }





        // private void on_time_block_added (Pomodoro.TimeBlock time_block)
        // {
        // }

        // private void on_time_block_removed (Pomodoro.TimeBlock time_block)
        // {
        // }

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


        // public static unowned Pomodoro.Session get_current ()
        // {
        //     if (Pomodoro.Session.instance == null) {
        //         var session = new Pomodoro.Session ();
        //         session.set_current ();
        //
        //         session.dispose.connect (() => {
        //             if (Session.instance == session) {
        //                 Session.instance = null;
        //             }
        //         });
        //     }
        //
        //     return Pomodoro.Session.instance;
        // }

        // public void set_current ()
        // {
        //     Pomodoro.Session.instance = this;
        // }

        // public bool is_current ()
        // {
        //     return Pomodoro.Session.instance == this;
        // }

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

        // public void reset ()
        // {
            // TODO
        // }

        // public void lookup_time_block (int time_block_id)
        // {
        // }

        /**
         * Setup new timeblock
         */
        // private void add_time_block (Pomodoro.TimeBlock time_block)
        // {
        // }

        /**
         * Schedule time-block preserving its start time.
         *
         * TODO: handle conflicts
         */
        /*
        public void schedule_time_block (Pomodoro.TimeBlock time_block)  // TODO: specify behavior on_conflict
                                         // requires (time_block.session == null)
        {
            if (this.contains (time_block)) {
                // TODO: warn block already belong to session
                return;
            }

            this.time_blocks.insert_sorted (time_block, Pomodoro.TimeBlock.compare);

            // TODO: handle/resolve conflicts

            time_block.session = this;

            this.time_block_added (time_block);
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

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            if (time_block == null) {
                // return first
                return this.time_blocks.nth_data (0);
            }

            return null;
        }

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            if (time_block == null) {
                // return last
            }

            return null;
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

        private void on_time_block_changed (Pomodoro.TimeBlock time_block)
        {

        }





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

        /**
         * Means insert sorted
         */
        public void insert (Pomodoro.TimeBlock time_block)
        {

        }

        public void insert_before (Pomodoro.TimeBlock time_block,
                                              Pomodoro.TimeBlock sibling)
                                       // requires (time_block.session == null)
        {
        }

        public void insert_after (Pomodoro.TimeBlock time_block,
                                  Pomodoro.TimeBlock sibling)
                                       // requires (time_block.session == null)
        {
        }

        private void remove (Pomodoro.TimeBlock time_block)
                                       // requires (time_block.session == this)
        {
            // if (!this.contains (time_block)) {
            //     return;
            // }

            unowned GLib.List<Pomodoro.TimeBlock> link = this.time_blocks.find (time_block);
            if (link == null) {
                // TODO: warn that block does not belong to session
                return;
            }

            this.time_blocks.delete_link (link);

            time_block.session = null;

            this.time_block_removed (time_block);
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

        // public signal void enter_time_block (Pomodoro.TimeBlock time_block)
        // {
            // state.notify["duration"].connect (this.on_state_duration_notify);
        // }

        // public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        // {
            // state.notify["duration"].disconnect (this.on_state_duration_notify);

            // this.score = state.calculate_score (this.score, this.timestamp);
        // }

    }
}
