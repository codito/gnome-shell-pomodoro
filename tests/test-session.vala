namespace Tests
{
    private uint8[] list_session_states (Pomodoro.Session session)
    {
        uint8[] states = {};

        session.@foreach ((time_block) => {
            states += (uint8) time_block.state;
        });

        return states;
    }


    public class SessionTest : Tests.TestSuite
    {
        private const uint POMODORO_DURATION = 1500;
        private const uint SHORT_BREAK_DURATION = 300;
        private const uint LONG_BREAK_DURATION = 900;
        private const uint POMODOROS_PER_SESSION = 4;

        public SessionTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new_from_template", this.test_new_from_template);

            // TODO: Tests methods for modifying history
            // this.add_test ("prepend", this.test_prepend);
            // this.add_test ("append", this.test_append);
            // this.add_test ("insert", this.test_insert);
            // this.add_test ("insert_before", this.test_insert_before);
            // this.add_test ("insert_after", this.test_insert_after);
            // this.add_test ("replace", this.test_replace);

            // TODO: Tests methods for modifying ongoing session
            // this.add_test ("extend", this.test_extend);
            // this.add_test ("shorten", this.test_shorten);

            // TODO: Tests for signals
            // this.add_test ("changed_signal", this.test_changed_signal);
            // this.add_test ("time_block_added_signal", this.test_time_block_added_signal);
            // this.add_test ("time_block_removed_signal", this.test_time_block_removed_signal);
            // this.add_test ("time_block_changed_signal", this.test_time_block_changed_signal);

            // TODO: Tests for propagating changes between blocks
            // this.add_test ("time_block_set_start_time", this.test_time_block_set_start_time);
            // this.add_test ("time_block_set_end_time", this.test_time_block_set_end_time);
            // this.add_test ("time_block_set_time_range", this.test_time_block_set_end_time);

            // TODO: methods for saving / restoring in db
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
         * Expect session not to have any time-blocks.
         */
        public void test_new ()
        {
            var session = new Pomodoro.Session ();

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

        /**
         * Check constructor `Session.from_template()`.
         *
         * Expect session to have time-blocks defined according to settings.
         */
        public void test_new_from_template ()
        {
            var now = Pomodoro.Timestamp.tick (0);
            var session = new Pomodoro.Session.from_template ();

            // uint8[] states = {};

            // session.@foreach ((time_block) => {
            //     states += (uint8) time_block.state;
            // });

            assert_cmpmem (
                list_session_states (session),
                {
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.SHORT_BREAK,
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.SHORT_BREAK,
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.SHORT_BREAK,
                    Pomodoro.State.POMODORO,
                    Pomodoro.State.LONG_BREAK
                }
            );
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
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionTest ()
    );
}
