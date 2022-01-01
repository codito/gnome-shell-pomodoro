namespace Tests
{
    public class SessionManagerTest : Tests.TestSuite
    {
        private Pomodoro.Timer default_timer;

        public SessionManagerTest ()
        {
            this.add_test ("new", this.test_new);
            // this.add_test ("new_with_timer", this.test_new_with_timer);
            // this.add_test ("test_set_current_time_block", this.test_set_current_time_block);
        }

        public override void setup ()
        {
            // default timer needs to be referenced somewhere
            this.default_timer = new Pomodoro.Timer ();
            this.default_timer.set_default ();

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
            var session_manager = new Pomodoro.SessionManager ();

            assert_true (session_manager.timer == Pomodoro.Timer.get_default ());
            assert_true (session_manager.timer.is_default ());

            // TODO: check current session / time-block
        }

        public void test_new_with_timer ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            assert_true (session_manager.timer == timer);
            assert_true (!session_manager.timer.is_default ());

            // TODO: check current session / time-block
        }

        public void test_set_current_time_block ()
        {
            var session    = new Pomodoro.Session.undefined ();
            var time_block = session.get_first_time_block ();
            assert_true (time_block.session == session);

            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var notify_current_time_block_emitted = 0;
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            var notify_current_session_emitted = 0;
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });

            // Set new time-block. Expect notify signals to be emitted
            session_manager.current_time_block = time_block;
            assert_true (timer.duration == time_block.state_duration);
            assert_true (timer.state.start_timestamp == time_block.start);
            assert_true (timer.state.offset == 0);

            assert_true (notify_current_time_block_emitted == 1);
            assert_true (notify_current_session_emitted == 1);

            // Set current time-block. Expect signals not to be emitted
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
            session_manager.current_time_block = session_manager.current_time_block;
            assert_true (notify_current_time_block_emitted == 0);
            assert_true (notify_current_session_emitted == 0);

            // Set new time-block within same session. Expect notify["current-session"] not to be emitted
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
            session_manager.current_time_block = session_manager.current_time_block;
            assert_true (notify_current_time_block_emitted == 1);
            assert_true (notify_current_session_emitted == 0);

            // Set current time-block with new session. Expect notify["current-session"] to be emitted
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
            session_manager.current_time_block = session_manager.current_time_block;
            assert_true (notify_current_time_block_emitted == 1);
            assert_true (notify_current_session_emitted == 1);
        }

        public void test_timer_start ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        }

        public void test_timer_stop ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        }

        public void test_timer_pause ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        }

        public void test_timer_resume ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        }

        public void test_timer_rewind ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        }

        public void test_timer_skip ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

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
