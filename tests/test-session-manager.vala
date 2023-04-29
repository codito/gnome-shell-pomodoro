namespace Tests
{
    public class SessionManagerTest : Tests.TestSuite
    {
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
            this.add_test ("set_current_session__null",
                           this.test_set_current_session__null);

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
            // this.add_test ("set_current_time_block__without_session",
            //                this.test_set_current_time_block__without_session);

            this.add_test ("set_scheduler",
                           this.test_set_scheduler);

            this.add_test ("advance", this.test_advance);
            this.add_test ("advance__paused", this.test_advance__paused);
            this.add_test ("advance_to_state__pomodoro", this.test_advance_to_state__pomodoro);
            this.add_test ("advance_to_state__break", this.test_advance_to_state__break);
            this.add_test ("advance_to_state__undefined", this.test_advance_to_state__undefined);
            this.add_test ("advance_to_state__extend_current_state", this.test_advance_to_state__extend_current_state);

            this.add_test ("expire_session", this.test_expire_session);

            this.add_test ("settings_change", this.test_settings_change);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND,
                                       Pomodoro.Interval.MICROSECOND);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

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

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);
        }


        /*
         * Tests for constructors
         */

        public void test_new ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1);
            settings.set_uint ("short-break-duration", 2);
            settings.set_uint ("long-break-duration", 3);
            settings.set_uint ("pomodoros-per-session", 10);

            var session_manager = new Pomodoro.SessionManager ();

            assert_true (session_manager.timer == this.timer);
            assert_true (session_manager.timer.is_default ());
            assert_false (session_manager.timer.is_started ());
            assert_false (session_manager.timer.is_running ());

            assert_null (session_manager.current_session);
            assert_null (session_manager.current_time_block);

            assert_cmpvariant (
                session_manager.scheduler.session_template.to_variant (),
                Pomodoro.SessionTemplate.with_defaults ().to_variant ()
            );
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

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);

            session_manager.enter_session.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_session = session_2;
                }
            });
            session_manager.current_session = session_1;
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "enter-session",
                "leave-session",
                "enter-session"
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

            session_manager.leave_session.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_session = session_3;
                }
            });
            session_manager.current_session = session_2;
            assert_true (session_manager.current_session == session_3);
            assert_null (session_manager.current_time_block);
            assert_cmpstrv (signals, {
                "leave-session",
                "enter-session"
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
            assert_cmpuint (session_manager.ref_count, GLib.CompareOperator.EQ, 1);

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
            session_manager.enter_time_block.connect ((session_manager_, time_block) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_session = session_2;
                }
            });

            session_manager.current_time_block = session_1.get_nth_time_block (1);

            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "leave-time-block",
                "enter-time-block",
                "leave-time-block",
                "leave-session",
                "enter-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 2);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);

            wait_for_object_finalized ((owned) session_manager);
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
            session_manager.leave_time_block.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_session = session_2;
                }
            });

            session_manager.current_time_block = session_1.get_nth_time_block (1);
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "leave-time-block",
                "leave-session",
                "enter-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);

            wait_for_object_finalized ((owned) session_manager);
        }

        public void test_set_current_session__null ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var session = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_time_block = session.get_first_time_block ();
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

            session_manager.current_session = null;
            assert_null (session_manager.current_time_block);
            assert_null (session_manager.current_session);
            assert_cmpstrv (signals, {
                "leave-time-block",
                "leave-session"
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_false (timer.is_started ());

            wait_for_object_finalized ((owned) session_manager);
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
                "leave-time-block",
                "enter-time-block"
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
                "leave-time-block",
                "leave-session",
                "enter-session",
                "enter-time-block"
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

            var session_1 = new Pomodoro.Session.from_template (this.session_template);
            var session_2 = new Pomodoro.Session.from_template (this.session_template);

            session_manager.enter_session.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_time_block = session_2.get_first_time_block ();
                }
            });
            session_manager.current_session = session_1;
            assert_true (session_manager.current_session == session_2);
            assert_cmpstrv (signals, {
                "enter-session",
                "leave-session",
                "enter-session",
                "enter-time-block"
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

            session_manager.leave_session.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_time_block = session_3.get_first_time_block ();
                }
            });
            session_manager.current_session = session_2;
            assert_true (session_manager.current_time_block == session_3.get_first_time_block ());
            assert_cmpstrv (signals, {
                "leave-session",
                "enter-session",
                "enter-time-block"
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

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            session_manager.enter_time_block.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_time_block = time_block_2;
                }
            });
            session_manager.current_time_block = time_block_1;
            assert_true (session_manager.current_time_block == time_block_2);
            assert_cmpstrv (signals, {
                "enter-session",
                "enter-time-block",
                "leave-time-block",
                "enter-time-block"
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

            session_manager.current_time_block = time_block_1;

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

            session_manager.leave_time_block.connect ((session_manager_, session) => {
                if (!handler_called) {
                    handler_called = true;
                    session_manager_.current_time_block = time_block_3;
                }
            });
            session_manager.current_time_block = time_block_2;
            assert_true (session_manager.current_time_block == time_block_3);
            assert_cmpstrv (signals, {
                "leave-time-block",
                "enter-time-block"
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

        // public void test_set_current_time_block__without_session ()
        // {
        //     var timer           = new Pomodoro.Timer ();
        //     var session_manager = new Pomodoro.SessionManager.with_timer (timer);
        //
        //     session_manager.current_time_block = new Pomodoro.TimeBlock (Pomodoro.State.UNDEFINED);
        //
        //     assert_null (session_manager.current_session);
        //     assert_null (session_manager.current_time_block);
        // }

        public void test_set_current_time_block__null ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var notify_current_time_block_emitted = 0;
            var notify_current_session_emitted = 0;
            var session = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_time_block = session.get_first_time_block ();
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

            session_manager.current_time_block = null;
            assert_null (session_manager.current_time_block);
            assert_true (session_manager.current_session == session);
            assert_cmpstrv (signals, {
                "leave-time-block",
            });
            assert_cmpint (notify_current_time_block_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpint (notify_current_session_emitted, GLib.CompareOperator.EQ, 0);
            assert_false (timer.is_started ());
        }


        /*
         * Tests for scheduler property
         */

        public void test_set_scheduler ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var signals = new string[0];
            var session = new Pomodoro.Session.from_template (this.session_template);
            session_manager.current_time_block = session.get_first_time_block ();
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            var scheduler_1 = session_manager.scheduler;
            scheduler_1.populated_session.connect (() => { signals += "scheduler_1:populated-session"; });;
            scheduler_1.rescheduled_session.connect (() => { signals += "scheduler_1:rescheduled-session"; });;

            var scheduler_2 = new Pomodoro.SimpleScheduler.with_template (this.session_template);
            scheduler_2.populated_session.connect (() => { signals += "scheduler_2:populated-session"; });;
            scheduler_2.rescheduled_session.connect (() => { signals += "scheduler_2:rescheduled-session"; });;

            var expected_time_block = session_manager.current_time_block;
            session_manager.scheduler = scheduler_2;

            assert_true (session_manager.scheduler == scheduler_2);
            assert_true (session_manager.current_time_block == expected_time_block);
            assert_cmpstrv (signals, {
                "scheduler_2:rescheduled-session",
            });
        }


        /*
         * Tests for advance_* methods
         */

        public void test_advance ()
        {
            var now             = Pomodoro.Timestamp.peek ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var changed_emitted = 0;
            var signals         = new string[0];

            // Start timer
            timer.start (now);

            var session = session_manager.current_session;
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (session.get_time_block_status (time_block_1) == Pomodoro.TimeBlockStatus.IN_PROGRESS);

            // Advance to next block
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance (now);
            assert_true (session_manager.current_session == session);
            assert_false (session_manager.current_time_block == time_block_1);
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
            assert_cmpstrv (signals, {
                "rescheduled-session",
                "leave-time-block",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
        }

        public void test_advance__paused ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var session = session_manager.current_session;
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;

            var expected_gap_start_time = now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);
            timer.pause (now);
            assert_true (timer.is_paused ());

            var expected_gap_end_time = now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance (now);
            assert_false (timer.is_paused ());

            time_block_1.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (expected_gap_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (expected_gap_end_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (time_block_1.end_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (time_block_2.start_time)
            );
        }

        public void test_advance_to_state__pomodoro ()
        {
            var now             = Pomodoro.Timestamp.peek ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var changed_emitted = 0;
            var signals         = new string[0];

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);

            session_manager.current_time_block = time_block_2;

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.POMODORO, now);
            assert_true (session_manager.current_session == session);
            assert_true (session_manager.current_time_block == time_block_3);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_3.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (session.get_time_block_status (time_block_1) == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (session.get_time_block_status (time_block_2) == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (session.get_time_block_status (time_block_3) == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_true (timer.is_started ());
            assert_cmpstrv (signals, {
                "rescheduled-session",
                "leave-time-block",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
        }

        public void test_advance_to_state__break ()
        {
            var now             = Pomodoro.Timestamp.peek ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var changed_emitted = 0;
            var signals         = new string[0];

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            session_manager.current_time_block = time_block_1;

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.BREAK, now);
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
            assert_true (timer.is_started ());
            assert_cmpstrv (signals, {
                "rescheduled-session",
                "leave-time-block",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
        }

        public void test_advance_to_state__undefined ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var changed_emitted = 0;
            var signals         = new string[0];

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            session_manager.current_time_block = time_block_1;

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            var now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.UNDEFINED, now);
            assert_true (session_manager.current_session == session);
            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (session.get_time_block_status (time_block_1) == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (session.get_time_block_status (time_block_2) == Pomodoro.TimeBlockStatus.SCHEDULED);
            assert_false (timer.is_started ());
            assert_cmpstrv (signals, {
                "rescheduled-session",  // reschedule is unnecessary
                "leave-time-block",
                "resolve-state",
                "state-changed"
            });
        }

        public void test_advance_to_state__extend_current_state ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var changed_emitted = 0;
            var signals         = new string[0];

            var now = Pomodoro.Timestamp.peek ();
            session_manager.advance_to_state (Pomodoro.State.BREAK, now);

            var session = session_manager.current_session;
            var time_block = session_manager.current_time_block;
            var expected_start_time = time_block.start_time;
            var expected_remaining_time = time_block.duration;

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.BREAK, now);

            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.state == Pomodoro.State.BREAK);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_true (session.get_time_block_status (time_block) == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_true (timer.is_started ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_remaining (now)),
                new GLib.Variant.int64 (expected_remaining_time)
            );
            assert_cmpstrv (signals, {
                "resolve-state",
                "rescheduled-session",
                "state-changed",
            });
        }


        /*
         * Tests for handling session expiry
         */

        public void test_expire_session ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var now             = Pomodoro.Timestamp.from_now ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);
            var main_context    = GLib.MainContext.@default ();

            session_manager.current_session = session;

            var has_expired = false;
            var elapsed = (uint) 0;
            var timeout_id = GLib.Timeout.add (100, () => {
                elapsed += 100;
                return GLib.Source.CONTINUE;
            });
            session.expiry_time = now + 500 * Pomodoro.Interval.MILLISECOND;
            session_manager.leave_session.connect (() => {
                has_expired = true;
            });

            while (!has_expired && elapsed < 2000) {
                main_context.iteration (true);
            }

            GLib.Source.remove (timeout_id);

            assert_true (has_expired);
            assert_null (session_manager.current_session);
            assert_false (timer.is_started ());
        }

        public void test_settings_change ()
        {
            var now             = Pomodoro.Timestamp.peek ();
            var session_manager = new Pomodoro.SessionManager ();
            var signals         = new string[0];
            var main_context = GLib.MainContext.@default ();
            session_manager.current_session = new Pomodoro.Session.from_template (this.session_template);

            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1);
            settings.set_uint ("short-break-duration", 2);
            settings.set_uint ("long-break-duration", 3);
            settings.set_uint ("pomodoros-per-session", 10);

            // Expect changes to be applied in idle
            assert_cmpstrv (signals, {});

            while (main_context.iteration (false));

            assert_cmpvariant (
                session_manager.scheduler.session_template.to_variant (),
                Pomodoro.SessionTemplate.with_defaults ().to_variant ()
            );
            assert_cmpstrv (signals, {
                "rescheduled-session",
            });
        }
    }


    /*
     * Tests for SessionManager, but with calls invoked by timer.
     */
    public class SessionManagerTimerTest : Tests.TestSuite
    {
        private Pomodoro.Timer timer;

        private Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        public SessionManagerTimerTest ()
        {
            this.add_test ("timer_set_state", this.test_timer_set_state);
            this.add_test ("timer_set_duration", this.test_timer_set_duration);

            this.add_test ("timer_start__initialize_session", this.test_timer_start__initialize_session);
            this.add_test ("timer_start__ignore_call", this.test_timer_start__ignore_call);
            this.add_test ("timer_start__continue_session", this.test_timer_start__continue_session);
            this.add_test ("timer_start__expire_session", this.test_timer_start__expire_session);

            this.add_test ("timer_reset__mark_end_of_current_time_block", this.test_timer_reset__mark_end_of_current_time_block);
            this.add_test ("timer_reset__paused", this.test_timer_reset__paused);
            this.add_test ("timer_reset__ignore_call", this.test_timer_reset__ignore_call);

            this.add_test ("timer_pause", this.test_timer_pause);
            this.add_test ("timer_resume", this.test_timer_resume);
            this.add_test ("timer_rewind", this.test_timer_rewind);
            this.add_test ("timer_rewind__paused", this.test_timer_rewind__paused);
            // this.add_test ("timer_suspended", this.test_timer_suspended);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND,
                                       Pomodoro.Interval.MICROSECOND);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

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

        public void test_timer_set_state ()
        {
            // TODO
        }

        public void test_timer_set_duration ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var session = session_manager.current_session;
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            var initial_duration = time_block_1.duration;
            var expected_duration = timer.duration + Pomodoro.Interval.MINUTE;
            var expected_elapsed = timer.calculate_elapsed (now);

            timer.duration = expected_duration;

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (expected_elapsed)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (expected_duration)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.duration),
                new GLib.Variant.int64 (expected_duration)
            );
            assert_cmpvariant (
                session_manager.current_session.get_time_block_meta (time_block_1).intended_duration,
                new GLib.Variant.int64 (initial_duration)
            );
            assert_true (session_manager.current_time_block == time_block_1);
            assert_true (
                session_manager.current_session.get_time_block_status (time_block_1) ==
                Pomodoro.TimeBlockStatus.IN_PROGRESS
            );
            assert_cmpstrv (signals, {
                "resolve-state",
                "rescheduled-session",
                "state-changed"
            });
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (time_block_1.end_time)
            );
        }

        /**
         * Check timer.start() call for a timer managed by session manager.
         *
         * Expect session manager to resolve timer state into a POMODORO time-block.
         */
        public void test_timer_start__initialize_session ()
        {
            var timer            = new Pomodoro.Timer ();
            var session_manager  = new Pomodoro.SessionManager.with_timer (timer);
            var session_template = session_manager.scheduler.session_template;
            var signals          = new string[0];

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            assert_null (session_manager.current_session);
            assert_false (timer.is_started ());
            assert_false (timer.is_running ());

            var now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.start (now);

            assert_nonnull (session_manager.current_session);
            assert_cmpuint (session_manager.current_session.cycles, GLib.CompareOperator.EQ, session_template.cycles);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_session.start_time),
                new GLib.Variant.int64 (timer.state.started_time)
            );
            assert_nonnull (session_manager.current_time_block);
            assert_true (session_manager.current_time_block == session_manager.current_session.get_first_time_block ());
            assert_true (session_manager.current_time_block.state == Pomodoro.State.POMODORO);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_time_block.start_time),
                new GLib.Variant.int64 (timer.state.started_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_time_block.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (session_template.pomodoro_duration)
            );
            assert_true (timer.user_data == session_manager.current_time_block);
            assert_true (timer.is_started ());
            assert_true (timer.is_running ());
            assert_cmpstrv (signals, {
                "populated-session",
                "enter-session",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
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
         * Stop the timer. Expect to start a new pomodoro when starting the timer again.
         */
        public void test_timer_start__continue_session ()
        {
            var now             = Pomodoro.Timestamp.peek ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];

            timer.start (now);

            var time_block_1 = session_manager.current_session.get_nth_time_block (0);
            var session = time_block_1.session;

            // Stop the timer
            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);

            assert_nonnull (session_manager.current_session);
            assert_null (session_manager.current_time_block);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);
            assert_true (
                session_manager.current_session.get_time_block_status (time_block_1) ==
                Pomodoro.TimeBlockStatus.UNCOMPLETED
            );

            // Start the timer again
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.start (now);

            var time_block_2 = session_manager.current_time_block;
            assert_true (time_block_2.state == Pomodoro.State.POMODORO);
            assert_true (session.get_next_time_block (time_block_1) == time_block_2);
            assert_true (
                session_manager.current_session.get_time_block_status (time_block_1) ==
                Pomodoro.TimeBlockStatus.UNCOMPLETED
            );
            assert_true (
                session_manager.current_session.get_time_block_status (time_block_2) ==
                Pomodoro.TimeBlockStatus.IN_PROGRESS
            );
            assert_cmpstrv (signals, {
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
        }

        /**
         * Start timer after 1h from last time-block. Expect previous session to expire.
         */
        public void test_timer_start__expire_session ()
        {
            var now                   = Pomodoro.Timestamp.peek ();
            var timer                 = new Pomodoro.Timer ();
            var session_manager       = new Pomodoro.SessionManager.with_timer (timer);
            var state_changed_emitted = 0;

            timer.start (now);
            assert_nonnull (session_manager.current_session);
            assert_nonnull (session_manager.current_time_block);
            assert_true (timer.is_started ());

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            var reset_time = now;
            timer.reset (now);
            assert_nonnull (session_manager.current_session);
            assert_null (session_manager.current_time_block);
            assert_false (timer.is_started ());

            now = Pomodoro.Timestamp.advance (Pomodoro.SessionManager.SESSION_EXPIRY_TIMEOUT);

            var expired_session = session_manager.current_session;
            expired_session.changed.connect (() => { state_changed_emitted++; });
            assert_true (expired_session.is_expired (now));

            timer.start (now);
            assert_false (session_manager.current_session == expired_session);
            assert_nonnull (session_manager.current_time_block);
            assert_true (timer.is_started ());
            assert_cmpint (state_changed_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (expired_session.end_time),
                new GLib.Variant.int64 (reset_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_session.start_time),
                new GLib.Variant.int64 (now)
            );
        }

        public void test_timer_reset__mark_end_of_current_time_block ()
        {
            var now             = Pomodoro.Timestamp.peek ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            timer.start (now);

            var time_block = session_manager.current_time_block;
            var session    = session_manager.current_session;
            var signals    = new string[0];
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);

            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now)
            );

            // Expect no rescheduled-session emission, as it's unnecessary. Rescheduling will be done when
            // resuming the session.
            assert_cmpstrv (signals, {
                "leave-time-block",
                "resolve-state",
                "rescheduled-session",  // the order is not important
                "state-changed",
            });
        }

        public void test_timer_reset__paused ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);
            timer.pause (now);

            var session = session_manager.current_session;
            var time_block = session_manager.current_time_block;
            var signals = new string[0];
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var expected_gap_start_time = now;
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);

            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now)
            );

            time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (expected_gap_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (now)
            );

            // Expect no rescheduled-session emission, as it's unnecessary. Rescheduling will be done when
            // resuming the session.
            assert_cmpstrv (signals, {
                "leave-time-block",
                "resolve-state",
                "rescheduled-session",  // the order is not important
                "state-changed",
            });
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

        public void test_timer_pause ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var current_time_block = session_manager.current_time_block;
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            var expected_gap_start_time = now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.pause (now);
            assert_true (timer.is_paused ());

            current_time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (expected_gap_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);  // reschedule seems unnecessary
        }

        public void test_timer_resume ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var current_time_block = session_manager.current_time_block;
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;

            var expected_current_time_block_start_time = current_time_block.start_time;
            var expected_current_time_block_end_time = current_time_block.end_time + Pomodoro.Interval.MINUTE;

            var expected_gap_start_time = now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);
            timer.pause (now);
            assert_true (timer.is_paused ());

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            var expected_gap_end_time = now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.resume (now);
            assert_false (timer.is_paused ());

            current_time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (expected_gap_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (expected_gap_end_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (current_time_block.start_time),
                new GLib.Variant.int64 (expected_current_time_block_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (current_time_block.end_time),
                new GLib.Variant.int64 (expected_current_time_block_end_time)
            );
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_timer_rewind ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var current_time_block = session_manager.current_time_block;
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            var expected_current_time_block_start_time = current_time_block.start_time;
            var expected_current_time_block_end_time = current_time_block.end_time + Pomodoro.Interval.MINUTE;

            var expected_gap_end_time = now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);
            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_false (timer.is_paused ());

            var expected_gap_start_time = expected_gap_end_time - Pomodoro.Interval.MINUTE;

            current_time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (expected_gap_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (expected_gap_end_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (current_time_block.start_time),
                new GLib.Variant.int64 (expected_current_time_block_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (current_time_block.end_time),
                new GLib.Variant.int64 (expected_current_time_block_end_time)
            );
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_timer_rewind__paused ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var signals         = new string[0];

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.pause (now);

            var current_time_block = session_manager.current_time_block;
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            var expected_gap_start_time = now - Pomodoro.Interval.MINUTE;
            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_true (timer.is_paused ());

            current_time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });

            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (expected_gap_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionManagerTest (),
        new Tests.SessionManagerTimerTest ()
    );
}
