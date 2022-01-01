namespace Pomodoro
{
    private const int64 TIME_TO_RESET_SESSION = 3600 * 1000000;  // microseconds


    /**
     * Pomodoro.Session class.
     *
     * As a "session" we call time from starting the timer to time it got reset.
     *
     * As a "cycle" we call a series of time blocks including a long break.
     * End of a long break or inactivity marks the end of a cycle.
     *
     * Session is responsible for:
     * - advising the timer as to when to take a long break
     * - scheduling upcoming time blocks
     */
    public class Session : GLib.Object
    {
        // public double score {
        //     get; set; default = 0.0;
        // }

        private GLib.List<Pomodoro.TimeBlock> time_blocks;

        public Session.undefined (int64 timestamp = -1)
        {
            if (timestamp < 0) {
                timestamp = Pomodoro.Timestamp.from_now ();
            }

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
            time_block.start = timestamp;

            this.append_time_block (time_block);
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

        public double get_progress (int64 timestamp = -1)
        {
            // TODO
            return 0.0;
        }

        public void reset ()
        {
            // TODO
        }

        // public void lookup_time_block (int time_block_id)
        // {
        // }

        /**
         * Schedule time-block preserving its start time.
         *
         * TODO: handle conflicts
         */
        public void schedule_time_block (Pomodoro.TimeBlock time_block)  // TODO: specify behavior on_conflict
        {
            // insert_sorted (owned G data, CompareFunc<G> compare_func);

            this.time_blocks.insert_sorted (time_block, Pomodoro.TimeBlock.compare);

            time_block.session = this;
        }

        /**
         * Add the time-block and align it with the last block.
         */
        public void append_time_block (Pomodoro.TimeBlock time_block)
        {
            var last_time_block = this.get_last_time_block ();

            this.time_blocks.append (time_block);

            // TODO
            // if (last_time_block != null) {
            //     time_block.shift (last_time_block.end - time_block.start);
            // }

            time_block.session = this;
        }

        public void remove_time_block (Pomodoro.TimeBlock time_block)
                                       requires (time_block.session == this)
        {
            // TODO

            time_block.session = null;
        }

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

        public void foreach_time_block (GLib.Func<unowned Pomodoro.TimeBlock> func)
        {
            this.time_blocks.@foreach (func);
        }

        public bool has_started (int64 timestamp = -1)
        {
            var first_time_block = this.get_first_time_block ();

            if (first_time_block != null) {
                return first_time_block.has_started (timestamp);
            }

            return false;
        }

        public bool has_ended (int64 timestamp = -1)
        {
            var last_time_block = this.get_first_time_block ();

            if (last_time_block != null) {
                return last_time_block.has_ended (timestamp);
            }

            return false;
        }

        public signal void enter_time_block (Pomodoro.TimeBlock time_block)
        {
            // state.notify["duration"].connect (this.on_state_duration_notify);
        }

        public signal void leave_time_block (Pomodoro.TimeBlock time_block)
        {
            // state.notify["duration"].disconnect (this.on_state_duration_notify);

            // this.score = state.calculate_score (this.score, this.timestamp);
        }

    }
}
