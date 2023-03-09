namespace Pomodoro
{
    /**
     * A threshold below which to mark time-blocks as invalid (or uncompleted).
     * We need it to be > 10 seconds to ignore accidental clicks; preferably 1 minute to keep history / stats clean.
     */
    private const int64 MIN_ELAPSED_TIME = Pomodoro.Interval.MINUTE;


    public enum Strictness
    {
        STRICT,
        LENIENT;

        /**
         * Return a fallback strictness if none is specified.
         */
        public static Pomodoro.Strictness get_default ()
        {
            // TODO: return from settings, not the `SessionManager`

            var session_manager = Pomodoro.SessionManager.get_default ();
            if (session_manager != null) {
                return session_manager.strictness;
            }

            return Pomodoro.Strictness.STRICT;
        }

        /**
         * Return whether time-block should be marked as completed or discarded.
         */
        public bool calculate_is_completed (Pomodoro.TimeBlock time_block,
                                            int64              timestamp)
        {
            var elapsed = time_block.calculate_elapsed (timestamp);
            var session = time_block.session;

            if (session == null || elapsed < MIN_ELAPSED_TIME) {
                return false;
            }

            switch (this) {
                case STRICT:
                    var time_block_meta = session.get_time_block_meta (time_block);

                    return elapsed >= time_block_meta.intended_duration / 2;

                case LENIENT:
                    return true;

                default:
                    assert_not_reached ();
            }
        }
    }
}
