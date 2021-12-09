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
        private GLib.List<Pomodoro.TimeBlock> time_blocks;
        private Pomodoro.TimeBlock? current_time_block = null;

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

        public double get_progress (int64 timestamp)
        {

        }

        public void reset ()
        {
            // TODO
        }

        public void append_time_block (Pomodoro.TimeBlock time_block)
        {

        }

        public TimerState? get_current_time_block ()
        {
            return this.current_state;
        }

        public TimerState? get_next_time_block (ulong state_id)
        {

        }

        public TimerState? get_previous_time_block (ulong state_id)
        {

        }

        public signal void enter_time_block (TimeBlock time_block)
        {
            state.notify["duration"].connect (this.on_state_duration_notify);
        }

        public signal void leave_time_block (TimeBlock time_block)
        {
            state.notify["duration"].disconnect (this.on_state_duration_notify);

            this.score = state.calculate_score (this.score, this.timestamp);
        }

    }
}
