namespace Tests
{
    private int64[] generate_random_timestamps (uint size)
    {
        var timestamps = new int64[size];
        var timestamp = (int64) 0;

        for (var index = 0; index < size; index++)
        {
            timestamp += GLib.Random.int_range (1, 1000);

            timestamps[index] = timestamp;
        }

        return timestamps;
    }


    public class TimezoneHistoryTest : Tests.TestSuite
    {
        private GLib.TimeZone? new_york_timezone;
        private GLib.TimeZone? london_timezone;

        public TimezoneHistoryTest ()
        {
            this.add_test ("insert__reverse_order",
                           this.test_insert__reverse_order);
            this.add_test ("insert__replace",
                           this.test_insert__replace);
            this.add_test ("insert__duplicate",
                           this.test_insert__duplicate);

            this.add_test ("search_marker__null",
                           this.test_search_marker__null);
            this.add_test ("search_marker__exact",
                           this.test_search_marker__exact);
            this.add_test ("search_marker__closest",
                           this.test_search_marker__closest);

            this.add_test ("fetch", this.test_fetch);
            this.add_test ("fetch__max", this.test_fetch__max);
        }

        public override void setup ()
        {
            try {
                this.new_york_timezone = new GLib.TimeZone.identifier ("America/New_York");
                this.london_timezone = new GLib.TimeZone.identifier ("Europe/London");
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            Pomodoro.Database.open ();
        }

        public override void teardown ()
        {
            Pomodoro.Database.close ();
        }

        public void test_insert__reverse_order ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (400, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);
            timezone_history.insert (200, this.new_york_timezone);

            unowned var marker_1 = timezone_history.search_marker (200);
            assert_nonnull (marker_1);
            assert_cmpstr (marker_1.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_1.timestamp),
                new GLib.Variant.int64 (200)
            );

            unowned var marker_2 = timezone_history.search_marker (400);
            assert_nonnull (marker_2);
            assert_cmpstr (marker_2.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_2.timestamp),
                new GLib.Variant.int64 (400)
            );
        }

        public void test_insert__replace ()
        {
            GLib.TimeZone? timezone;

            var timezone_history = new Pomodoro.TimezoneHistory ();

            timezone_history.insert (200, this.new_york_timezone);
            timezone = timezone_history.search (200);
            assert_nonnull (timezone);
            assert_cmpstr (timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");

            timezone_history.insert (200, this.london_timezone);
            timezone = timezone_history.search (200);
            assert_nonnull (timezone);
            assert_cmpstr (timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");
        }

        public void test_insert__duplicate ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.new_york_timezone);

            unowned var marker = timezone_history.search_marker (300);
            assert_nonnull (marker);
            assert_cmpstr (marker.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker.timestamp),
                new GLib.Variant.int64 (200)
            );
        }

        public void test_search_marker__null ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);

            unowned var marker = timezone_history.search_marker (199);
            assert_null (marker);
        }

        public void test_search_marker__exact ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);
            timezone_history.insert (400, this.new_york_timezone);

            unowned var marker_1 = timezone_history.search_marker (200);
            assert_nonnull (marker_1);
            assert_cmpstr (marker_1.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_1.timestamp),
                new GLib.Variant.int64 (200)
            );

            unowned var marker_2 = timezone_history.search_marker (300);
            assert_nonnull (marker_2);
            assert_cmpstr (marker_2.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_2.timestamp),
                new GLib.Variant.int64 (300)
            );

            unowned var marker_3 = timezone_history.search_marker (400);
            assert_nonnull (marker_3);
            assert_cmpstr (marker_3.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_3.timestamp),
                new GLib.Variant.int64 (400)
            );
        }

        public void test_search_marker__closest ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (200, this.new_york_timezone);
            timezone_history.insert (300, this.london_timezone);

            unowned var marker_1 = timezone_history.search_marker (201);
            assert_nonnull (marker_1);
            assert_cmpstr (marker_1.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "America/New_York");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_1.timestamp),
                new GLib.Variant.int64 (200)
            );

            unowned var marker_2 = timezone_history.search_marker (400);
            assert_nonnull (marker_2);
            assert_cmpstr (marker_2.timezone.get_identifier (),
                           GLib.CompareOperator.EQ,
                           "Europe/London");
            assert_cmpvariant (
                new GLib.Variant.int64 (marker_2.timestamp),
                new GLib.Variant.int64 (300)
            );
        }

        public void test_fetch ()
        {
            var timezone_history = new Pomodoro.TimezoneHistory ();
            var timestamps = generate_random_timestamps (1000);

            for (var index = 0; index < timestamps.length; index++)
            {
                timezone_history.insert (
                    timestamps[index],
                    (index & 1) == 0 ? this.new_york_timezone : this.london_timezone);
            }

            // Destroy one instance to check if entries have been saved and a new instance is
            // fetching it properly.
            timezone_history = null;
            timezone_history = new Pomodoro.TimezoneHistory ();

            for (var index = 0; index < timestamps.length; index++)
            {
                unowned var marker = timezone_history.search_marker (timestamps[index]);
                assert_nonnull (marker);
                assert_cmpstr (
                    marker.timezone.get_identifier (),
                    GLib.CompareOperator.EQ,
                    (index & 1) == 0 ? "America/New_York" : "Europe/London"
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (marker.timestamp),
                    new GLib.Variant.int64 (timestamps[index])
                );
            }
        }

        public void test_fetch__max ()
        {
            var timestamp = Pomodoro.Timestamp.MAX;

            var timezone_history = new Pomodoro.TimezoneHistory ();
            timezone_history.insert (timestamp, this.new_york_timezone);

            // Destroy one instance to check if entries have been saved and a new instance is
            // fetching it properly.
            timezone_history = null;
            timezone_history = new Pomodoro.TimezoneHistory ();

            unowned var marker = timezone_history.search_marker (timestamp);
            assert_nonnull (marker);
            assert_cmpstr (
                marker.timezone.get_identifier (),
                GLib.CompareOperator.EQ,
                "America/New_York"
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (marker.timestamp),
                new GLib.Variant.int64 (timestamp)
            );
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimezoneHistoryTest ()
    );
}
