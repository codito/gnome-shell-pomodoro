namespace Tests
{
    public class SessionTest : Tests.TestSuite
    {
        private const uint POMODORO_DURATION = 1500;
        private const uint SHORT_BREAK_DURATION = 300;
        private const uint LONG_BREAK_DURATION = 900;
        private const uint POMODOROS_PER_SESSION = 4;

        public SessionTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new-empty", this.test_new_empty);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", POMODORO_DURATION);
            settings.set_uint ("short-break-duration", SHORT_BREAK_DURATION);
            settings.set_uint ("long-break-duration", LONG_BREAK_DURATION);
            settings.set_uint ("pomodoros-per-session", POMODOROS_PER_SESSION);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        /**
         * Check constructor `Session()`.
         *
         * Expect session to have time-blocks defined according to settings.
         */
        public void test_new ()
        {
            var now = Pomodoro.Timestamp.tick (0);
            var session = new Pomodoro.Session ();
            uint8[] states = {};

            session.@foreach ((time_block) => {
                states += (uint8) time_block.state;
            });

            assert_cmpmem (states, {
                Pomodoro.State.POMODORO,
                Pomodoro.State.SHORT_BREAK,
                Pomodoro.State.POMODORO,
                Pomodoro.State.SHORT_BREAK,
                Pomodoro.State.POMODORO,
                Pomodoro.State.SHORT_BREAK,
                Pomodoro.State.POMODORO,
                Pomodoro.State.LONG_BREAK
            });
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (
                    session.start_time + Pomodoro.Interval.SECOND * (
                        POMODORO_DURATION * POMODOROS_PER_SESSION +
                        SHORT_BREAK_DURATION * (POMODOROS_PER_SESSION - 1) +
                        LONG_BREAK_DURATION
                    )
                )
            );
        }

        /**
         * Check constructor `Session.empty()`.
         *
         * Expect session not to have any time-blocks.
         */
        public void test_new_empty ()
        {
            var session = new Pomodoro.Session.empty ();

            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MIN)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MAX)
            );

            var first_time_block = session.get_first_time_block ();
            assert_null (first_time_block);

            var last_time_block = session.get_last_time_block ();
            assert_null (last_time_block);
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
