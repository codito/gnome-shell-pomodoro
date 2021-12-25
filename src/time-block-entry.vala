namespace Pomodoro
{
    // TODO: This will replace Pomodoro.Entry class
    private class TimeBlockEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 session_id { get; set; }
        public int64 parent_id { get; set; }

        /* Start timestamp */
        public int64 start { get; set; }

        /* End timestamp */
        public int64 end { get; set; }

        /* Time that should not be counted as part of the time-block */
        public int64 gap { get; set; }

        /* Elapsed time at the time entry was finalized */
        public int64 elapsed { get; set; }

        /**
         * State code:
         *   - 'P' for State.POMODORO
         *   - 'S' for State.SHORT_BREAK
         *   - 'L' for State.LONG_BREAK
         *   - 'U' for State.UNDEFINED
         */
        public char state { get; set; }

        /* Intended state duration, as in settings */
        public int64 state_duration { get; set; }

        /* Finalized entries are aggregated in stats */
        public bool finalized { get; set; }
    }
}
