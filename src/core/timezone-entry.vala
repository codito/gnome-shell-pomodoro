using GLib;


namespace Pomodoro
{
    private class TimezoneEntry : Gom.Resource
    {
        public int64 id { get; set; }
        public int64 time { get; set; }
        public string identifier { get; set; }

        static construct
        {
            set_table ("timezones");
            set_primary_key ("id");
            set_unique ("time");
            set_notnull ("time");
            set_notnull ("identifier");
        }
    }
}
