namespace Tests
{
    public class TimeBlockTest : Tests.TestSuite
    {
        public TimeBlockTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("state", this.test_state);
            this.add_test ("start", this.test_start);
            this.add_test ("end", this.test_end);
            this.add_test ("duration", this.test_duration);
            this.add_test ("parent", this.test_parent);
            this.add_test ("set_range", this.test_set_range);
            this.add_test ("has_bounds", this.test_has_bounds);
            this.add_test ("has_started", this.test_has_started);
            this.add_test ("has_ended", this.test_has_ended);
            this.add_test ("get_elapsed", this.test_get_elapsed);
            this.add_test ("get_remaining", this.test_get_remaining);
            this.add_test ("get_progress", this.test_get_progress);
            this.add_test ("add_child", this.test_add_child);
            this.add_test ("remove_child", this.test_remove_child);
            this.add_test ("get_last_child", this.test_get_last_child);
            this.add_test ("foreach_child", this.test_foreach_child);
            this.add_test ("changed_range_signal", this.test_changed_range_signal);
        }

        public override void setup ()
        {
            // var settings = Pomodoro.get_settings ()
            //                        .get_child ("preferences");
            // settings.set_double ("pomodoro-duration", POMODORO_DURATION);
            // settings.set_double ("short-break-duration", SHORT_BREAK_DURATION);
            // settings.set_double ("long-break-duration", LONG_BREAK_DURATION);
            // settings.set_double ("long-break-interval", LONG_BREAK_INTERVAL);
            // settings.set_boolean ("pause-when-idle", false);
        }

        public override void teardown ()
        {
            // var settings = Pomodoro.get_settings ();
            // settings.revert ();
        }

        public void test_new ()
        {
        }

        public void test_state ()
        {

        }

        public void test_start ()
        {

        }

        public void test_end ()
        {

        }

        public void test_duration ()
        {

        }

        public void test_parent ()
        {

        }

        public void test_set_range ()
        {

        }

        public void test_has_bounds ()
        {

        }

        public void test_has_started ()
        {

        }

        public void test_has_ended ()
        {

        }

        public void test_get_elapsed ()
        {

        }

        public void test_get_remaining ()
        {

        }

        public void test_get_progress ()
        {

        }

        public void test_add_child ()
        {

        }

        public void test_remove_child ()
        {

        }

        public void test_get_last_child ()
        {
        }

        public void test_foreach_child ()
        {

        }

        public void test_changed_range_signal ()
        {

        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimeBlockTest ()
    );
}
