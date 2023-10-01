namespace Pomodoro
{
    private class SessionEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 start { get; set; }
        public int64 end { get; set; }

        /**
         * Date string in local timezone.
         * It implies that all timeblocks within a session that has started previous day will be
         * counted for previous day.
         */
        public string date { get; set; }

        static construct
        {
            set_table ("sessions");
            set_primary_key ("id");
            set_notnull ("date");
        }

        public void set_datetime (GLib.DateTime value)
        {
            this.date = value.to_local ().format ("%Y-%m-%dT%H:%M:%S");
        }

        public GLib.DateTime? get_datetime ()
        {
            return new GLib.DateTime.from_iso8601 (this.date, new GLib.TimeZone.local ());
        }
    }
}
