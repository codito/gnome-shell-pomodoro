namespace Tests
{
    // private int count_pomodoros (Pomodoro.Session session)
    // {
    //     var pomodoro_count = 0;
    //     session_manager.current_session.@foreach ((time_block) => {
    //         if (time_block.state == Pomodoro.State.POMODRO)
    //         pomodoro_count += 1;
    //     });
    // }


    // private uint8[] list_session_states (Pomodoro.Session session)
    // {
    //     uint8[] states = {};
    //
    //     session.@foreach ((time_block) => {
    //         states += (uint8) time_block.state;
    //     });
    //
    //     return states;
    // }


    public class SessionManagerTest : Tests.TestSuite
    {
        // private const uint POMODORO_DURATION = 1500;
        // private const uint SHORT_BREAK_DURATION = 300;
        // private const uint LONG_BREAK_DURATION = 900;
        // private const uint POMODOROS_PER_SESSION = 4;

        private Pomodoro.Timer timer;

        private Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        public SessionManagerTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new_with_timer", this.test_new_with_timer);

            this.add_test ("set_current_session",
                           this.test_set_current_session);
            this.add_test ("set_current_session__while_entering_session",
                           this.test_set_current_session__while_entering_session);
            this.add_test ("set_current_session__while_leaving_session",
                           this.test_set_current_session__while_leaving_session);
            this.add_test ("set_current_session__while_entering_time_block",
                           this.test_set_current_session__while_entering_time_block);
            this.add_test ("set_current_session__while_leaving_time_block",
                           this.test_set_current_session__while_leaving_time_block);
            // this.add_test ("set_current_session__null",
            //                this.test_set_current_session__null);
            // this.add_test ("set_current_session__mark_as_skipped",
            //                this.test_set_current_session__mark_as_skipped);

            this.add_test ("set_current_time_block",
                           this.test_set_current_time_block);
            this.add_test ("set_current_time_block__while_entering_session",
                           this.test_set_current_time_block__while_entering_session);
            this.add_test ("set_current_time_block__while_leaving_session",
                           this.test_set_current_time_block__while_leaving_session);
            this.add_test ("set_current_time_block__while_entering_time_block",
                           this.test_set_current_time_block__while_entering_time_block);
            this.add_test ("set_current_time_block__while_leaving_time_block",
                           this.test_set_current_time_block__while_leaving_time_block);
            this.add_test ("set_current_time_block__null",
                           this.test_set_current_time_block__null);
            this.add_test ("set_current_time_block__with_new_session",
                           this.test_set_current_time_block__with_new_session);
            this.add_test ("set_current_time_block__without_session",
                           this.test_set_current_time_block__without_session);
            // this.add_test ("set_current_time_block__mark_as_skipped",
            //                this.test_set_current_time_block__mark_as_skipped);

            this.add_test ("set_strictness",
                           this.test_set_strictness);
            // this.add_test ("set_strategy",
            //                this.test_set_strategy);

            // TODO:
            //  - expire_session__after_idle
            //  - expire_session__after_pause
            //  - expire_session  ...
            //  - modifying current time-block - whether it's trimmed / skipped
            //  - modifying current session - whether it's rebuild, time-blocks skipped
            //  - test things related to srategy / strictness
            //     -

            // this.add_test ("timer_set_state", this.test_timer_set_state);
            // this.add_test ("timer_set_duration", this.test_timer_set_duration);
            this.add_test ("timer_start__initialize_session", this.test_timer_start__initialize_session);
            this.add_test ("timer_start__ignore_call", this.test_timer_start__ignore_call);
            this.add_test ("timer_start__expire_session", this.test_timer_start__expire_session);
            // TODO: extend current time-block ?

            this.add_test ("timer_reset__mark_end_of_current_time_block", this.test_timer_reset__mark_end_of_current_time_block);
            this.add_test ("timer_reset__ignore_call", this.test_timer_reset__ignore_call);

            // this.add_test ("timer_pause", this.test_timer_pause);
            // this.add_test ("timer_reset", this.test_timer_reset);
            this.add_test ("timer_skip", this.test_timer_skip);
            // this.add_test ("timer_rewind", this.test_timer_reset);
            // this.add_test ("timer_suspended", this.test_timer_suspended);

            // this.add_test ("settings_change", this.test_settings_change);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            this.timer = new Pomodoro.Timer ();

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

            Pomodoro.Timer.set_default (null);
        }


        /*
         * Tests for constructors
         */

        public void test_new ()
        {
            var session_manager = new Pomodoro.SessionManager ();

            assert_true (session_manager.timer == this.timer);
            assert_true (session_manager.timer.is_default ());
            assert_false (session_manager.timer.is_started ());
            assert_false (session_manager.timer.is_running ());

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);
        }

        public void test_new_with_timer ()
        {
            var timer = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            assert_true (session_manager.timer == timer);
            assert_false (session_manager.timer.is_default ());
            assert_false (session_manager.timer.is_started ());
            assert_false (session_manager.timer.is_running ());

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);
        }


        /*
         * Tests for current-session property
         */

        public void test_set_current_session ()
        {
            var timer           = this.timer;
            var session_manager = new Pomodoro.SessionManager.with_timer (this.timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var resolve_state_emitted = 0;
            var state_changed_emitted = 0;

            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });
            timer.resolve_state.connect (() => { resolve_state_emitted++; });
            timer.state_changed.connect (() => { state_changed_emitted++; });

            var session_1 = new Pomodoro.Session ();
            var session_2 = new Pomodoro.Session.from_template (this.session_template);

            // Set empty session. Expect session to be set as current despite having no time-blocks.
            session_manager.current_session = session_1;
            assert_true (session_manager.current_session == session_1);
            assert_null (session_manager.current_time_block);
            assert_cmpstrv (signals, {"enter-session"});
            signals.resize (0);

            // Set non-empty session. Expect current-time-block to become null.
            session_manager.current_session = session_2;
            assert_true (session_manager.current_session == session_2);
            assert_null (session_manager.current_time_block);
            assert_cmpstrv (signals, {
                "leave-session", "enter-session"
            });
            assert_null (timer.user_data);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.SECOND)
            );
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            signals.resize (0);

            // Set current-session with same session. Expect to it to be ignored.
            session_manager.current_session = session_manager.current_session;
            assert_cmpstrv (signals, {});

            // Set current-session to null.
            session_manager.current_session = null;
            assert_cmpstrv (signals, {
                "leave-session"
            });
            assert_null (timer.user_data);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (0 * Pomodoro.Interval.SECOND)
            );
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());
            signals.resize (0);
        }

        public void test_set_current_session__while_entering_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);

            session_manager.enter_session.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_session = session_2;
                }
            });
            session_manager.current_session = session_1;
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "enter-session", "leave-session", "enter-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 0);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 2);
        }

        public void test_set_current_session__while_leaving_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);
            var session_3 = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_session = session_1;

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            session_manager.leave_session.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_session = session_3;
                }
            });
            session_manager.current_session = session_2;
            assert_true (session_manager.current_session == session_3);
            assert_null (session_manager.current_time_block);
            assert_cmpstrv (signals, {
                "leave-session", "enter-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 0);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_set_current_session__while_entering_time_block ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_time_block = session_1.get_first_time_block ();

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });
            session_manager.enter_time_block.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_session = session_2;
                }
            });

            session_manager.current_time_block = session_1.get_nth_time_block (1);
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "leave-time-block", "enter-time-block", "leave-time-block", "leave-session",
                "enter-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_set_current_session__while_leaving_time_block ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_time_block = session_1.get_first_time_block ();

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });
            session_manager.leave_time_block.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_session = session_2;
                }
            });

            session_manager.current_time_block = session_1.get_nth_time_block (1);
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "leave-time-block", "leave-session", "enter-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
        }


        /*
         * Tests for current-time-block property
         */

        public void test_set_current_time_block ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;

            // timer.resolve_state.connect (() => { signals += "resolve-state"; });
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            var session_1    = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session_1.get_first_time_block ();
            var time_block_2 = session_1.get_next_time_block (time_block_1);

            var session_2    = new Pomodoro.Session.from_template (this.session_template);
            var time_block_3 = session_2.get_first_time_block ();

            // assert_nonnull (time_block_1);
            // assert_nonnull (time_block_2);

            // Set empty session. Expect to set session as current, despite having no time-block yet.
            session_manager.current_time_block = time_block_1;
            assert_true (session_manager.current_time_block == time_block_1);
            assert_true (session_manager.current_session == session_1);
            assert_cmpstrv (signals, {
                "enter-session", "enter-time-block"
            });
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            signals.resize (0);
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;

            // Set current time-block. Expect signals not to be emitted
            session_manager.current_time_block = session_manager.current_time_block;
            assert_cmpstrv (signals, {});
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 0);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);
            signals.resize (0);
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;

            // Set current-time-block within same session.
            session_manager.current_time_block = time_block_2;
            assert_true (session_manager.current_time_block == time_block_2);
            assert_true (session_manager.current_session == session_1);
            assert_cmpstrv (signals, {
                "leave-time-block", "enter-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);
            signals.resize (0);
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;

            // Set current-time-block with new session.
            session_manager.current_time_block = time_block_3;
            assert_true (session_manager.current_time_block == time_block_3);
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "leave-time-block", "leave-session", "enter-session", "enter-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
            signals.resize (0);
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;

            // Set current-time-block to null. Expect session not to be changed.
            session_manager.current_time_block = null;
            assert_null (session_manager.current_time_block);
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "leave-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);
            signals.resize (0);
            notify_current_time_block_emitted = 0;
            notify_current_session_emitted = 0;
        }

        public void test_set_current_time_block__while_entering_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);

            session_manager.enter_session.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_time_block = session_2.get_first_time_block ();
                }
            });
            session_manager.current_session = session_1;
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "enter-session", "leave-session", "enter-session", "enter-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 2);
        }

        public void test_set_current_time_block__while_leaving_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);
            var session_3 = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_session = session_1;

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            session_manager.leave_session.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_time_block = session_3.get_first_time_block ();
                }
            });
            session_manager.current_session = session_2;
            assert_true (session_manager.current_time_block == session_3.get_first_time_block ());
            assert_cmpstrv (signals, {
                "leave-session", "enter-session", "enter-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_set_current_time_block__while_entering_time_block ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            session_manager.enter_time_block.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_time_block = time_block_2;
                }
            });
            session_manager.current_time_block = time_block_1;
            assert_true (session_manager.current_time_block == time_block_2);
            assert_cmpstrv (signals, {
                "enter-session", "enter-time-block", "leave-time-block", "enter-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_set_current_time_block__while_leaving_time_block ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var handler_called = false;

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);

            // var session_2 = new Pomodoro.Session.from_template (this.session_template);
            // var session_3 = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_time_block = time_block_1;

            // this.setup_signals (session_manager, ref signals);
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            // session_manager.notify["current-session"].connect (() => { signals += "notify::current-session"; });
            // session_manager.notify["current-time-block"].connect (() => { signals += "notify::current-time-block"; });
            session_manager.notify["current-session"].connect (() => {
                notify_current_session_emitted++;
            });
            session_manager.notify["current-time-block"].connect (() => {
                notify_current_time_block_emitted++;
            });

            session_manager.leave_time_block.connect (() => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager.current_time_block = time_block_3;
                }
            });
            session_manager.current_time_block = time_block_2;
            assert_true (session_manager.current_time_block == time_block_3);
            assert_cmpstrv (signals, {
                "leave-time-block", "enter-time-block"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);
        }

        public void test_set_current_time_block__with_new_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);
            var time_block      = session.get_first_time_block ();

            session_manager.current_time_block = time_block;

            assert_true (session_manager.current_session == session);
            assert_true (session_manager.current_time_block == time_block);
        }

        public void test_set_current_time_block__without_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.current_time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);
        }

        public void test_set_current_time_block__null ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);
            var time_block      = session.get_first_time_block ();

            session_manager.current_time_block = time_block;
            session_manager.current_time_block = null;

            assert_true (session_manager.current_session == session);
            assert_null (session_manager.current_time_block);
        }


        /*
         * Tests for strictness property
         */
        public void test_set_strictness ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var notify_strictness_emitted = 0;
            session_manager.notify["strictness"].connect (() => {
                notify_strictness_emitted++;
            });

            session_manager.strictness = Pomodoro.Strictness.STRICT;
            assert_cmpint (notify_strictness_emitted, GLib.CompareOperator.EQ, 0);  // unchanged

            session_manager.strictness = Pomodoro.Strictness.LENIENT;
            assert_cmpint (notify_strictness_emitted, GLib.CompareOperator.EQ, 1);

            session_manager.strictness = Pomodoro.Strictness.LENIENT;
            assert_cmpint (notify_strictness_emitted, GLib.CompareOperator.EQ, 1);  // unchanged
        }


        /*
         * Tests for strategy property
         */
        // public void test_set_strategy ()
        // {
        //     var timer           = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        //     var strategy_1 = new Pomodoro.StrictSessionManagerStrategy ();
        //     var strategy_2 = new Pomodoro.AdaptiveSessionManagerStrategy ();

        //     var notify_strategy_emitted = 0;
        //     session_manager.notify["strategy"].connect (() => {
        //         notify_strategy_emitted++;
        //     });

        //     session_manager.strategy = strategy_1;
        //     assert_cmpint (notify_strategy_emitted, GLib.CompareOperator.EQ, 1);

        //     session_manager.strategy = strategy_1;
        //     assert_cmpint (notify_strategy_emitted, GLib.CompareOperator.EQ, 1);  // unchanged

        //     session_manager.strategy = strategy_2;
        //     assert_cmpint (notify_strategy_emitted, GLib.CompareOperator.EQ, 2);

        //     session_manager.strategy = null;
        //     assert_cmpint (notify_strategy_emitted, GLib.CompareOperator.EQ, 3);
        // }


        /*
         * Tests for methods
         */

        // public void test_initialize_session ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            // TODO
        // }

        // public void test_advance_to_time_block ()
        // {
            // TODO
        // }

        // public void test_advance_to_state ()
        // {
            // TODO
        // }

        // public void test_advance ()
        // {
            // TODO
        // }


        /*
         * Tests for calls performed on timer
         */

        /**
         * Check timer.start() call for a timer managed by session manager.
         *
         * Expect session manager to resolve timer state into a POMODORO time-block.
         */
        public void test_timer_start__initialize_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];
            // timer.resolve_state.connect (() => { signals += "resolve-state"; });
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            debug ("### A");

            timer.start ();

            debug ("### B");

            assert_nonnull (session_manager.current_session);
            assert_cmpuint (session_manager.current_session.get_cycles_count (), GLib.CompareOperator.EQ, 4);
            // assert_cmpmem (
            //     list_session_states (session_manager.current_session),
            //     {
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK
            //     }
            // );
            assert_nonnull (session_manager.current_time_block);
            assert_true (session_manager.current_time_block == session_manager.current_session.get_first_time_block ());
            assert_true (session_manager.current_time_block.state == Pomodoro.State.POMODORO);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (this.session_template.pomodoro_duration)
            );
            // assert_true (timer.user_data == session_manager.current_time_block);
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());

            // Expect timer to be setup before enter-* signals are emitted.
            assert_cmpstrv (signals, {"enter-session", "enter-time-block"});
        }

        /**
         * Call timer.start() while timer is already running. Expect call to be ignored.
         */
        public void test_timer_start__ignore_call ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            timer.start ();

            var expected_time_block = session_manager.current_time_block;
            var expected_state      = timer.state.copy ();
            var signals             = new string[0];
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.start ();

            assert_cmpvariant (
                timer.state.to_variant (),
                expected_state.to_variant ()
            );
            assert_true (session_manager.current_time_block == expected_time_block);
            assert_cmpstrv (signals, {});
        }

        /**
         * Start timer after 1h from last time-block. Expect previous session to expire.
         */
        public void test_timer_start__expire_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];

            debug ("Timer.start()");
            timer.start ();
            assert_nonnull (session_manager.current_session);
            assert_nonnull (session_manager.current_time_block);
            assert_true (timer.is_started ());

            debug ("Timer.reset()");
            timer.reset ();
            assert_nonnull (session_manager.current_session);
            assert_null (session_manager.current_time_block);
            assert_false (timer.is_started ());

            // timer.resolve_state.connect (() => { signals += "resolve-state"; });
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            // Pomodoro.Timestamp.advance (Pomodoro.Session.EXPIRE_TIMEOUT);
            Pomodoro.Timestamp.advance (Pomodoro.SessionManager.SESSION_EXPIRY_TIMEOUT);
            assert_false (timer.is_started ());
            assert_true (session_manager.current_session.is_expired ());

            var expired_session = session_manager.current_session;
            timer.start ();

            assert_false (session_manager.current_session == expired_session);
            assert_cmpstrv (signals, {
                "leave-session", "enter-session", "enter-time-block"
            });
            assert_nonnull (session_manager.current_time_block);
            assert_true (timer.is_started ());

            Pomodoro.Timestamp.advance (Pomodoro.Interval.SECOND);
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed ()),
                new GLib.Variant.int64 (Pomodoro.Interval.SECOND)
            );
        }

        public void test_timer_reset__mark_end_of_current_time_block ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            // session_manager.current_session = new Pomodoro.Session.from_template ();
            timer.start ();
            assert_nonnull (session_manager.current_time_block);

            var current_time_block = session_manager.current_time_block;
            var current_session    = session_manager.current_session;
            var signals            = new string[0];
            // timer.resolve_state.connect (() => { signals += "resolve-state"; });
            // timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            var now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset ();

            // As the timer is stopped, expect current time-block to be null.
            assert_null (session_manager.current_time_block);
            assert_cmpstrv (signals, {
                "leave-time-block"
            });

            // Expect session manager to modify blocks end-time.
            assert_cmpvariant (
                new GLib.Variant.int64 (current_time_block.end_time),
                new GLib.Variant.int64 (now)
            );

            // Expect following time-blocks also to be shifted.
            // var next_time_block = current_session.get_next_time_block (current_time_block);
            // assert_cmpvariant (
            //     new GLib.Variant.int64 (next_time_block.start_time),
            //     new GLib.Variant.int64 (current_time_block.end_time)
            // );
        }

        /**
         * Timer.reset() should be ignored when there is no current-time-block.
         */
        public void test_timer_reset__ignore_call ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset ();

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);
            assert_cmpstrv (signals, {});
        }

        // public void test_timer_pause ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_timer_resume ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_timer_rewind ()
        // {
        //     var timer = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);

        // }

        // public void test_enter_session_signal ()
        // {
        //     var timer           = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);
        //
        //     session_manager.current_session = new Pomodoro.Session ();
        //
        //     session_manager.current_session = new Pomodoro.Session ();
        // }

        // public void test_enter_time_block_signal ()
        // {
        //     var timer           = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);
        //
        //     session_manager.current_session = new Pomodoro.Session ();
        //
        //     session_manager.current_session = new Pomodoro.Session ();
        // }

        public void test_timer_skip ()
        {
            var timer               = new Pomodoro.Timer ();
            var session_manager     = new Pomodoro.SessionManager.with_timer (timer);
            var now                 = Pomodoro.Timestamp.from_now ();
            var changed_emitted = 0;

            var session      = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);
            var time_block_4 = session.get_last_time_block ();

            // debug ("set session_manager.current_session");
            session_manager.current_session = session;
            assert_true (session_manager.current_session == session);
            assert_null (session_manager.current_time_block);
            assert_false (session_manager.current_session.is_expired ());

            session.changed.connect (() => { changed_emitted++; });

            // Skip within session
            // debug ("Timer.start()");
            timer.start ();
            assert_true (session_manager.current_session == session);
            // assert_cmpint (session.index (session_manager.current_time_block), GLib.CompareOperator.EQ, 0);
            assert_true (session_manager.current_time_block == time_block_1);
            assert_cmpint (changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (session.get_time_block_status (time_block_1) == Pomodoro.TimeBlockStatus.IN_PROGRESS);

            // debug ("Timer.skip()");
            timer.skip ();
            assert_true (session_manager.current_session == session);
            assert_true (session_manager.current_time_block == time_block_2);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (session.get_time_block_status (time_block_1) == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (session.get_time_block_status (time_block_2) == Pomodoro.TimeBlockStatus.IN_PROGRESS);

            // debug ("Timer.skip()");
            timer.skip ();
            assert_true (session_manager.current_session == session);
            assert_true (session_manager.current_time_block == time_block_3);

            // TODO:
            // - check signals emitted
            // - check timer duration/elapsed
            // - check time-block end-time/start-time

            // Skip to next session
            session_manager.current_time_block = time_block_4;
            timer.skip ();
            assert_false (session_manager.current_session == session);
            assert_true (session_manager.current_time_block == session_manager.current_session.get_first_time_block ());
        }

        // TODO
        // public void test_timer_skip__when_paused ()
        // {
        // }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionManagerTest ()
    );
}
