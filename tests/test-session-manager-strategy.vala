namespace Tests
{
    public abstract class SessionManagerStrategyTest : Tests.TestSuite
    {
        protected Pomodoro.Timer default_timer;

        protected Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            // Default timer needs to be referenced somewhere
            this.default_timer = new Pomodoro.Timer ();
            this.default_timer.set_default ();

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("pomodoros-per-session", 4);
            // settings.set_boolean ("pause-when-idle", false);
        }

        public override void teardown ()
        {
            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }
    }

    public class StrictSessionManagerStrategyTest : SessionManagerStrategyTest
    {
        public StrictSessionManagerStrategyTest ()
        {
            this.add_test ("mark_time_block_completed",
                           this.test_mark_time_block_completed);
            this.add_test ("reschedule",
                           this.test_reschedule);
        }

        public void test_mark_time_block_completed ()
        {
            var strategy = new Pomodoro.StrictSessionManagerStrategy ();


        }

        public void test_reschedule ()
        {
        }
    }


    public class AdaptiveSessionManagerStrategyTest : SessionManagerStrategyTest
    {
        // private Pomodoro.Timer default_timer;

        // private Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
        //     pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
        //     short_break_duration = 5 * Pomodoro.Interval.MINUTE,
        //     long_break_duration = 15 * Pomodoro.Interval.MINUTE,
        //     cycles = 4
        // };

        public AdaptiveSessionManagerStrategyTest ()
        {
            // this.add_test ("mark_time_block_completed",
            //                this.test_mark_time_block_completed);
            // this.add_test ("reschedule",
            //                this.test_reschedule);
        }

        // public override void setup ()
        // {
        //     Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            // Default timer needs to be referenced somewhere
        //     this.default_timer = new Pomodoro.Timer ();
        //     this.default_timer.set_default ();

        //     var settings = Pomodoro.get_settings ();
        //     settings.set_uint ("pomodoro-duration", 1500);
        //     settings.set_uint ("short-break-duration", 300);
        //     settings.set_uint ("long-break-duration", 900);
        //     settings.set_uint ("pomodoros-per-session", 4);
            // settings.set_boolean ("pause-when-idle", false);
        // }

        // public override void teardown ()
        // {
        //     var settings = Pomodoro.get_settings ();
        //     settings.revert ();
        // }

    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.StrictSessionManagerStrategyTest (),
        new Tests.AdaptiveSessionManagerStrategyTest ()
    );
}
