namespace Tests
{
    public class SessionManagerTest : Tests.TestSuite
    {
        public SessionManagerTest ()
        {
            this.add_test ("new", this.test_new);
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
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionManagerTest ()
    );
}
