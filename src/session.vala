namespace Pomodoro
{
    private const int64 TIME_TO_RESET_SESSION = 3600 * 1000000;  // microseconds


    /**
     * Pomodoro.Session class.
     *
     * As a "session" we call a series of time blocks including a long break.
     * End of a long break or inactivity marks the end of a session.
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
        private Pomodoro.TimeBlock? current_time_block = null;

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

        public void add_time_block (Pomodoro.TimeBlock time_block)
        {
        }

        public void remove_time_block (Pomodoro.TimeBlock time_block)
        {
        }

        public unowned Pomodoro.TimeBlock? get_current_time_block ()
        {
            return this.current_time_block;
        }

        public unowned Pomodoro.TimeBlock? get_first_time_block ()
        {
            return this.time_blocks.nth_data (0);
        }

        public unowned Pomodoro.TimeBlock? get_next_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            return null;
        }

        public unowned Pomodoro.TimeBlock? get_previous_time_block (Pomodoro.TimeBlock? time_block = null)
        {
            return null;
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
