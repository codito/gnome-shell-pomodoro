namespace Pomodoro
{
    /**
     * Scheduler lets find empty blocks of time.
     *
     * In future we would like to align time-blocks to calendar events and working time,
     * hence it's separated to a helper class.
     *
     * Scheduler should be aware of all events. It's not aware of already scheduled time-blocks
     * since we don't need conflict resolution.
     */
    public class Scheduler : GLib.Object
    {
        /**
         * Fit time-block to first available slot.
         *
         * Try to preserve time blocks original duration.
         * It must be autonomous - pick best candidate in case of conflict.
         */
        public bool fit (Pomodoro.TimeBlock time_block,
                         int64              minimum_start_time,
                         int64              natural_start_time)
        {
            // TODO

            return true;
        }

        /**
         * Fit time-blocks to available time.
         *
         * Like `fit()`, but additionally allows to spread time-blocks more evenly in case of conflict.
         */
        public bool fit_many (Pomodoro.TimeBlock[] time_blocks,
                              int64                minimum_start_time,
                              int64                natural_start_time)
        {
            // TODO

            return true;
        }
    }
}
