namespace Tests
{
    public class SessionTest : Tests.TestSuite
    {
        // int64 timestamp = 0;

        public SessionTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new-undefined", this.test_new_undefined);
        }

        public override void setup ()
        {
            // Pomodoro.freeze_time ();

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

        /**
         * Check constructor `Session()`.
         *
         * Expect session not to have any time-blocks yet.
         */
        public void test_new ()
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var session = new Pomodoro.Session ();

            // assert (!session.has_started (timestamp));
            // assert (!session.has_ended (timestamp));

            var time_blocks_count = 0;
            session.foreach_time_block (() => {
                time_blocks_count++;
            });

            assert (time_blocks_count == 0);
        }

        /**
         * Check constructor `Session.undefined()`.
         *
         * Expect session to have one undefined time-block.
         */
        public void test_new_undefined ()
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var session = new Pomodoro.Session.undefined (timestamp);

            // assert (session.has_started (timestamp));
            // assert (!session.has_started (timestamp - 1));
            // assert (!session.has_ended (timestamp));

            var first_time_block = session.get_first_time_block ();
            assert (first_time_block != null);
            assert (first_time_block.state == Pomodoro.State.UNDEFINED);

            var last_time_block = session.get_last_time_block ();
            assert (last_time_block != null);
            assert (last_time_block == first_time_block);
        }

    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionTest ()
    );
}
