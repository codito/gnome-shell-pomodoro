namespace Pomodoro
{
    public class GapEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 time_block_id { get; set; }
        public int64 start_time { get; set; }
        public int64 end_time { get; set; }

        internal ulong version = 0;

        static construct
        {
            set_table ("gaps");
            set_primary_key ("id");
            set_notnull ("time-block-id");
            set_notnull ("start-time");
            set_notnull ("end-time");
            set_unique ("start-time");
            set_reference ("time-block-id", "time_blocks", "id");
        }
    }
}
