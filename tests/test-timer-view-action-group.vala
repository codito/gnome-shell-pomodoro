namespace Tests
{
    public class TimerViewActionGroupTest : Tests.TestSuite
    {
        private Pomodoro.Timer?          timer;
        private Pomodoro.SessionManager? session_manager;

        public TimerViewActionGroupTest ()
        {
            this.add_test ("new",
                           this.test_new);
            this.add_test ("start",
                           this.test_start);
            // this.add_test ("stop",
            //                this.test_stop);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);

            this.timer = new Pomodoro.Timer ();
            this.session_manager = new Pomodoro.SessionManager.with_timer (this.timer);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.thaw ();

            this.timer = null;
            this.session_manager = null;
        }


        public void test_new ()
        {
            var action_group = new Pomodoro.TimerViewActionGroup (this.session_manager);

            assert_true (action_group.session_manager == this.session_manager);
            assert_true (action_group.timer == this.timer);

            // TODO: check added actions
        }

        public void test_start ()
        {
            var now = Pomodoro.Timestamp.tick (0);
            var action_group = new Pomodoro.TimerViewActionGroup (this.session_manager);

            action_group.activate_action ("start", null);

            assert_true (this.timer.is_running ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );

            // TODO: check current session
            assert_nonnull (this.session_manager.current_session);


            // TODO: check current time-block
            assert_nonnull (this.session_manager.current_time_block);
        }

        public void test_stop ()
        {
            // TODO
            assert_not_reached ();
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimerViewActionGroupTest ()
    );
}
