namespace Pomodoro
{
    /**
     * A lightweight equivalent of `TimezoneEntry`
     */
    [Compact]
    public class TimezoneMarker
    {
        public int64         timestamp;
        public GLib.TimeZone timezone;

        public TimezoneMarker (int64         timestamp,
                               GLib.TimeZone timezone)
        {
            this.timestamp = timestamp;
            this.timezone  = timezone;
        }
    }


    /**
     * We use UTC timestamp throughout the app and store local timezone separately
     * as a way to convert it to local time when needed.
     *
     * Internally, data is stored from most recent to oldest entries. Be aware that
     * `GLib.TimeZone` timestamps are in seconds while ours are in microseconds.
     */
    [SingleInstance]
    public class TimezoneHistory : GLib.Object
    {
        private const uint FETCH_LIMIT = 50;

        private GLib.Array<Pomodoro.TimezoneMarker> data;
        private int64 fetched_timestamp = Pomodoro.Timestamp.UNDEFINED;
        private bool fetched_all = false;

        construct
        {
            this.data = new GLib.Array<Pomodoro.TimezoneMarker> ();
        }

        /**
         * Try to fill in data.
         *
         * Returns the number of fetched entries.
         */
        private uint fetch ()
        {
            Gom.Filter? filter = null;

            if (this.fetched_all) {
                return 0U;
            }

            if (Pomodoro.Timestamp.is_defined (this.fetched_timestamp)) {
                filter = new Gom.Filter.lt (typeof (Pomodoro.TimezoneEntry),
                                            "time",
                                            this.fetched_timestamp);
            }

            var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
            sorting.add (typeof (Pomodoro.TimezoneEntry), "time", Gom.SortingMode.DESCENDING);

            var repository = Pomodoro.Database.get_repository ();

            try {
                var results = repository.find_sorted_sync (typeof (Pomodoro.TimezoneEntry),
                                                           filter,
                                                           sorting);
                var results_count = results.count;
                var fetch_count = uint.min (results_count, FETCH_LIMIT);

                results.fetch_sync (0, fetch_count);

                for (var index = 0; index < fetch_count; index++)
                {
                    var entry = (Pomodoro.TimezoneEntry) results.get_index (index);

                    this.data.append_val (this.create_marker (
                            entry.time,
                            new GLib.TimeZone.identifier (entry.identifier)));
                    this.fetched_timestamp = entry.time;
                }

                if (results_count < FETCH_LIMIT) {
                    this.fetched_all = true;
                }

                return fetch_count;
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to fetch timezones: %s", error.message);
            }

            return 0U;
        }

        private inline void search_internal (int64                                timestamp,
                                             out unowned Pomodoro.TimezoneMarker? marker,
                                             out uint                             index)
        {
            marker = null;
            index = 0U;

            var _index = index;

            do {
                while (_index < this.data.length)
                {
                    unowned var _marker = this.data.index (_index);

                    if (timestamp >= _marker.timestamp) {
                        marker = _marker;
                        index = _index;
                        return;
                    }

                    _index++;
                }
            }
            while (this.fetch () > 0);
        }

        /**
         * Scan from most recent to oldest markers
         */
        public unowned Pomodoro.TimezoneMarker? search_marker (int64 timestamp)
                                                               requires (timestamp >= 0)
        {
            unowned Pomodoro.TimezoneMarker? marker;

            this.search_internal (timestamp, out marker, null);

            return marker;
        }

        public GLib.TimeZone? search (int64 timestamp)
        {
            unowned Pomodoro.TimezoneMarker? marker;

            this.search_internal (timestamp, out marker, null);

            return marker?.timezone;
        }

        private inline Pomodoro.TimezoneMarker create_marker (int64         timestamp,
                                                              GLib.TimeZone timezone)
        {
            return new Pomodoro.TimezoneMarker (timestamp, timezone);
        }

        public void insert (int64         timestamp,
                            GLib.TimeZone timezone)
                            requires (timestamp >= 0)
        {
            unowned Pomodoro.TimezoneMarker? existing_marker;
            uint index;

            this.search_internal (timestamp, out existing_marker, out index);

            if (existing_marker != null)
            {
                if (existing_marker.timezone.get_identifier () == timezone.get_identifier ()) {
                    return;  // avoid inserting duplicates
                }

                if (existing_marker.timestamp == timestamp) {
                    this.data.remove_index (index);  // replacing existing marker
                }

                this.data.insert_val (index, this.create_marker (timestamp, timezone));
            }
            else {
                this.data.append_val (this.create_marker (timestamp, timezone));
            }

            var entry = new Pomodoro.TimezoneEntry ();
            entry.repository = Pomodoro.Database.get_repository ();
            entry.time = timestamp;
            entry.identifier = timezone.get_identifier ();

            try {
                entry.save_sync ();
            }
            catch (GLib.Error error) {
                GLib.warning ("Failed to save timezone: %s", error.message);
            }
        }

        // public void @foreach (int64                        start_time,
        //                       int64                        end_time,
        //                       Pomodoro.ForeachTimezoneFunc func)
        // {
        // }
    }
}
