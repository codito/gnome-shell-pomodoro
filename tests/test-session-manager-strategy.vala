namespace Tests
{

    /*
     * Fixtures
     */

    /*
    private Pomodoro.TimerState create_initial_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   void* user_data = null)
    {
        return Pomodoro.TimerState () {
            duration = duration,
            offset = 0,
            started_time = Pomodoro.Timestamp.UNDEFINED,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_started_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 0 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            started_time = timestamp,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_paused_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 0 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            started_time = timestamp,
            paused_time = now,
            finished_time = Pomodoro.Timestamp.UNDEFINED,
            user_data = user_data
        };
    }

    private Pomodoro.TimerState create_finished_state (
                                   int64 duration = 10 * Pomodoro.Interval.MINUTE,
                                   int64 elapsed = 10 * Pomodoro.Interval.MINUTE,
                                   int64 timestamp = -1,
                                   void* user_data = null)
    {
        var now = Pomodoro.Timestamp.from_now ();

        if (timestamp < 0) {
            timestamp = now - elapsed;
        }

        return Pomodoro.TimerState () {
            duration = duration,
            offset = now - timestamp - elapsed,
            started_time = timestamp,
            paused_time = Pomodoro.Timestamp.UNDEFINED,
            finished_time = now,
            user_data = user_data
        };
    }
    */


    /*
     * Helpful functions
     */

    private bool is_completed (Pomodoro.TimeBlock time_block)
    {
        return time_block.get_data<bool> ("completed");
    }

    private bool is_skipped (Pomodoro.TimeBlock time_block)
    {
        return time_block.get_data<bool> ("skipped");
    }

    /*
     * Test classes
     */

    public abstract class SessionManagerStrategyTest : Tests.TestSuite
    {
        protected Pomodoro.Timer timer;
        protected Pomodoro.SessionManager session_manager;

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
            this.timer = new Pomodoro.Timer ();
            this.timer.set_default ();

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("pomodoros-per-session", 4);
            // settings.set_boolean ("pause-when-idle", false);

            this.session_manager = new Pomodoro.SessionManager.with_timer (this.timer);
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
            this.add_test ("reschedule__move_later",
                           this.test_reschedule__move_later);
            this.add_test ("reschedule__add_extra_cycle",
                           this.test_reschedule__add_extra_cycle);

            this.add_test ("session_manager_advance",
                           this.test_session_manager_advance);

            this.add_test ("timer_start",
                           this.test_timer_start);
            this.add_test ("timer_pause",
                           this.test_timer_pause);
            this.add_test ("timer_pause_resume",
                           this.test_timer_pause_resume);
            this.add_test ("timer_skip",
                           this.test_timer_skip);

            this.add_test ("timer_suspended__stopped",
                           this.test_timer_suspended__stopped);
            this.add_test ("timer_suspended__pomodoro",
                           this.test_timer_suspended__pomodoro);
            this.add_test ("timer_suspended__break",
                           this.test_timer_suspended__break);
            this.add_test ("timer_suspended__paused_pomodoro",
                           this.test_timer_suspended__paused_pomodoro);
            this.add_test ("timer_suspended__paused_break",
                           this.test_timer_suspended__paused_break);

            // this.add_test ("test_become_idle__stopped",
            //                this.test_become_idle__stopped);
            // this.add_test ("test_become_idle__pomodoro",
            //                this.test_become_idle__pomodoro);
            // this.add_test ("test_become_idle__break",
            //                this.test_become_idle__break);
            // this.add_test ("test_become_idle__paused_pomodoro",
            //                this.test_become_idle__paused_pomodoro);
            // this.add_test ("test_become_idle__paused_break",
            //                this.test_become_idle__paused_break);
        }

        public void test_reschedule__move_later ()
        {
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session_manager = new Pomodoro.SessionManager ();
            session_manager.strategy = strategy;


        }

        public void test_reschedule__add_extra_cycle ()
        {
            // TODO
        }

        /**
         * Expect time-blocks to be marked as completed when session manager advances time-blocks.
         */
        public void test_session_manager_advance ()
        {
            var timer           = new Pomodoro.Timer ();
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            session_manager.strategy = strategy;

            // TODO: Use manually SessionManager.advance() here

        }

        /**
         * Expect time-blocks to be marked as completed when session manager advances time-blocks.
         */
        public void test_timer_start ()
        {
            var timer           = new Pomodoro.Timer ();
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            session_manager.strategy = strategy;

            timer.start ();

            var first_time_block = session_manager.current_time_block;
            assert_false (is_completed (first_time_block));

            // let time pass until last second
            Pomodoro.Timestamp.tick (timer.calculate_remaining () - Pomodoro.Interval.SECOND);
            timer.tick ();
            assert_true (session_manager.current_time_block == first_time_block);
            assert_false (is_completed (first_time_block));

            // let the last second pass
            // expect pomodoro to be marked as completed
            Pomodoro.Timestamp.tick (Pomodoro.Interval.SECOND);
            timer.tick ();
            assert_false (session_manager.current_time_block == first_time_block);
            assert_true (is_completed (first_time_block));

            // TODO: Use manually SessionManager.adance() here
        }

        /**
         * Expect that Timer.pause() won't affect scoring.
         * Leaving it idle for 1h should wipe the session.
         */
        public void test_timer_pause ()
        {

            // TODO: expect rescheduled not to be emitted
            // TODO: check if session expires after 1h
        }

        /**
         * Expect that Timer.pause() / .resume() won't affect scoring.
         */
        public void test_timer_pause_resume ()
        {
            var timer           = new Pomodoro.Timer ();
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            session_manager.strategy = strategy;
            timer.start ();

            var first_time_block = session_manager.current_time_block;
            assert_false (is_completed (first_time_block));

            // introduce gap
            timer.pause ();
            Pomodoro.Timestamp.tick (Pomodoro.Interval.MINUTE);
            timer.resume ();

            // let time pass until last second
            Pomodoro.Timestamp.tick (timer.calculate_remaining () - Pomodoro.Interval.SECOND);
            timer.tick ();
            assert_true (session_manager.current_time_block == first_time_block);
            assert_false (is_completed (first_time_block));

            // let the last second pass
            // expect pomodoro to be marked as completed
            Pomodoro.Timestamp.tick (Pomodoro.Interval.SECOND);
            timer.tick ();
            assert_false (session_manager.current_time_block == first_time_block);
            assert_true (is_completed (first_time_block));

            // TODO: expect rescheduled to be emitted 1 time
            // TODO: don't expect extra cycle
        }

        /**
         * Expect that Timer.skip() won't mark time-blocks as completed.
         * Skipping a pomodoro should result in rescheduling and adding extra cycle.
         */
        public void test_timer_skip ()
        {
            var timer           = new Pomodoro.Timer ();
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            session_manager.strategy = strategy;
            timer.start ();

            var first_time_block = session_manager.current_time_block;
            assert_false (is_completed (first_time_block));

            // let time pass until last second
            Pomodoro.Timestamp.tick (timer.calculate_remaining () - Pomodoro.Interval.SECOND);
            timer.tick ();
            assert_true (session_manager.current_time_block == first_time_block);
            assert_false (is_completed (first_time_block));
            assert_false (is_skipped (first_time_block));

            // skip before one second
            // expect pomodoro not to be marked as completed
            timer.skip ();
            assert_false (session_manager.current_time_block == first_time_block);
            assert_false (is_completed (first_time_block));
            assert_true (is_skipped (first_time_block));

            // TODO: expect rescheduled to be emitted 1 time
            // TODO: expect extra cycle
        }

        /**
         * Timer.reset() indicates it stopped.
         * Expect session to be wiped after 1h.
         */
        public void test_timer_reset ()
        {
            var timer           = new Pomodoro.Timer ();
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            session_manager.strategy = strategy;
            timer.start ();

            // TODO: wipe current session if user manually resetted the session

            // var first_time_block = session_manager.current_time_block;
            // assert_false (is_completed (first_time_block));

            // let time pass until last second
            // Pomodoro.Timestamp.tick (timer.calculate_remaining () - Pomodoro.Interval.SECOND);
            // timer.tick ();
            // assert_true (session_manager.current_time_block == first_time_block);
            // assert_false (is_completed (first_time_block));

            // skip before one second
            // expect pomodoro not to be marked as completed
            // timer.skip ();
            // assert_false (session_manager.current_time_block == first_time_block);
            // assert_false (is_completed (first_time_block));

            // Outdate TODO-s?
            // TODO: expect rescheduled to be emitted 1 time
            // TODO: don't expect extra cycle
            // TODO: check if session expires after 1h
        }

        public void test_timer_suspended__stopped ()
        {
            // TODO: expect small suspend not to cause anyting
            // TODO: expect 1h to wipe the session
        }

        public void test_timer_suspended__pomodoro ()
        {
            // TODO: expect small suspend not to cause anyting
            // TODO: expect 1h to wipe the session
        }

        public void test_timer_suspended__break ()
        {
            // TODO: expect small suspend not to cause anyting
            // TODO: expect 1h to wipe the session
        }

        public void test_timer_suspended__paused_pomodoro ()
        {
            // TODO: expect small suspend not to cause anyting
            // TODO: expect 1h to wipe the session
        }

        public void test_timer_suspended__paused_break ()
        {
            // TODO: expect small suspend not to cause anyting
            // TODO: expect 1h to wipe the session
        }


        // public void test_become_idle__stopped ()
        // {
        // }

        // public void test_become_idle__pomodoro ()
        // {
        // }

        // public void test_become_idle__break ()
        // {
        // }

        // public void test_become_idle__paused_pomodoro ()
        // {
        // }

        // public void test_become_idle__paused_break ()
        // {
        // }
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




        /*
        public void test_advance_time_blocks__exact ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var strategy        = new Pomodoro.StrictSessionManagerStrategy ();
            var session         = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
                    short_break_duration = 5 * Pomodoro.Interval.MINUTE,
                    long_break_duration = 15 * Pomodoro.Interval.MINUTE,
                    cycles = 1
                }
            );

            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            // setup and start first pomodoro
            session_manager.strategy = strategy;
            session_manager.current_session = session;
            timer.start ();
            assert_true (session_manager.current_time_block == time_block_1);
            assert_false (is_completed (session_manager.current_time_block));

            // advance to break
            // expect pomodoro to be marked as completed
            Pomodoro.Timestamp.tick (timer.calculate_remaining ());
            timer.tick ();
            assert_false (session_manager.current_time_block == time_block_1);
            assert_true (session_manager.current_time_block == time_block_2);
            assert_true (is_completed (time_block_1));
            assert_false (is_completed (time_block_2));

            // finish break
            Pomodoro.Timestamp.tick (timer.calculate_remaining ());
            timer.tick ();
            assert_true (is_completed (time_block_2));
        }
        */

        /*
        public void test_advance_time_blocks__exact ()
        {
            var now        = Pomodoro.Timestamp.from_now ();
            var timer      = new Pomodoro.Timer ();
            var strategy   = new Pomodoro.StrictSessionManagerStrategy ();
            var time_block = new Pomodoro.TimeBlock ();
            time_block.set_time_range (now, now + Pomodoro.Interval.HOUR);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            session_manager.strategy = strategy;
            session_manager.current_session = session;

            timer.start ();
            assert_true (session_manager.current_time_block == time_block);
            assert_false (is_completed (time_block));

            // let time pass
            // expect pomodoro to be marked as completed
            Pomodoro.Timestamp.tick (timer.calculate_remaining ());
            timer.tick ();
            assert_false (session_manager.current_time_block == time_block);
            assert_true (is_completed (time_block));
        }
        */

