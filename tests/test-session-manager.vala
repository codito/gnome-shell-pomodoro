namespace Tests
{
    private double EPSILON = 0.0001;


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

            this.add_test ("advance__pomodoro", this.test_advance__pomodoro);
            this.add_test ("advance__paused_pomodoro", this.test_advance__paused_pomodoro);
            this.add_test ("advance__uncompleted_long_break", this.test_advance__uncompleted_long_break);
            this.add_test ("advance__completed_long_break", this.test_advance__completed_long_break);
            this.add_test ("advance__uniform_breaks", this.test_advance__uniform_breaks);
            this.add_test ("advance_to_state__pomodoro", this.test_advance_to_state__pomodoro);
            this.add_test ("advance_to_state__short_break", this.test_advance_to_state__short_break);
            this.add_test ("advance_to_state__undefined", this.test_advance_to_state__undefined);
            this.add_test ("advance_to_state__extend_pomodoro", this.test_advance_to_state__extend_pomodoro);
            this.add_test ("advance_to_state__extend_short_break", this.test_advance_to_state__extend_short_break);
            this.add_test ("advance_to_state__extend_long_break", this.test_advance_to_state__extend_long_break);
            this.add_test ("advance_to_state__switch_breaks", this.test_advance_to_state__switch_breaks);
            this.add_test ("advance_to_state__completed_session", this.test_advance_to_state__completed_session);

            this.add_test ("confirm_starting_break", this.test_confirm_starting_break);
            this.add_test ("confirm_starting_pomodoro", this.test_confirm_starting_pomodoro);

            this.add_test ("reset", this.test_reset);
            this.add_test ("expire_session__after_timeout", this.test_expire_session__after_timeout);
            this.add_test ("expire_session__after_suspend", this.test_expire_session__after_suspend);

            this.add_test ("settings_change", this.test_settings_change);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);
            Pomodoro.Timestamp.set_auto_advance (Pomodoro.Interval.MICROSECOND);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);
        }

        public override void teardown ()
        {
            var settings = Pomodoro.get_settings ();
            settings.revert ();

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);
        }

        public Pomodoro.Session create_session (Pomodoro.SessionManager session_manager)
        {
            var scheduler = session_manager.scheduler;
            var session = new Pomodoro.Session.from_template (scheduler.session_template);
            session.@foreach (
                (time_block) => {
                    time_block.set_intended_duration (time_block.duration);
                    time_block.set_completion_time (scheduler.calculate_time_block_completion_time (time_block));
                }
            );

            return session;
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
            settings.set_uint ("cycles", 5);

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
                "leave-session",
                "enter-session"
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

        public void test_advance__pomodoro ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var session_changed_emitted = 0;
            var signals = new string[0];

            // Start timer
            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var session = session_manager.current_session;
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.get_completion_time ()),
                new GLib.Variant.int64 (session_manager.scheduler.calculate_time_block_completion_time (time_block_1))
            );
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);

            // Skip to a short-break after a minute
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session.changed.connect (() => { session_changed_emitted++; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance (now);
            assert_true (session_manager.current_session == session);
            assert_false (session_manager.current_time_block == time_block_1);
            assert_true (session_manager.current_time_block == time_block_2);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);
            assert_true (time_block_2.state == Pomodoro.State.SHORT_BREAK);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (time_block_2.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_cmpstrv (signals, {
                "rescheduled-session",
                "leave-time-block",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Skipping to next state while being paused should keep timer paused.
         */
        public void test_advance__paused_pomodoro ()
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

        /**
         * Skipping uncompleted long break should add extra cycle.
         */
        public void test_advance__uncompleted_long_break ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.ensure_session ();

            var session = session_manager.current_session;
            var cycles = session.get_cycles ().length ();
            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var time_block = session_manager.current_session.get_last_time_block ();
            Pomodoro.Timestamp.freeze_to (time_block.start_time);
            session_manager.current_time_block = time_block;

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance ();

            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (session_manager.current_session == session);
            assert_cmpuint (session.get_cycles ().length (), GLib.CompareOperator.EQ, cycles + 1);
        }

        /**
         * Skipping completed long break should start new session.
         */
        public void test_advance__completed_long_break ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.ensure_session ();

            var session = session_manager.current_session;
            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var time_block = session_manager.current_session.get_last_time_block ();
            Pomodoro.Timestamp.freeze_to (time_block.start_time);
            session_manager.current_time_block = time_block;

            Pomodoro.Timestamp.advance (12 * Pomodoro.Interval.MINUTE);
            session_manager.advance ();

            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.COMPLETED);
            assert_true (session_manager.current_session != session);
        }

        /**
         * When has-uniform-breaks is true, expect POMODORO advance to a BREAK.
         */
        public void test_advance__uniform_breaks ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_uint ("cycles", 1);

            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            // Start timer
            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var session = session_manager.current_session;
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            assert_true (session_manager.has_uniform_breaks);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);
            assert_true (time_block_2.state == Pomodoro.State.BREAK);

            // Advance to a break once pomodoro finishes
            session_manager.advance (time_block_1.end_time);
            assert_true (session_manager.current_session == session);
            assert_false (session_manager.current_time_block == time_block_1);
            assert_true (session_manager.current_time_block == time_block_2);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);
            assert_true (time_block_2.state == Pomodoro.State.BREAK);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.duration),
                new GLib.Variant.int64 (session_manager.scheduler.session_template.short_break_duration)
            );
        }

        /**
         * Discard time-blocks shorter than 10s.
         */
        public void test_advance__min_elapsed ()
        {
            // TODO
        }

        public void test_advance_to_state__pomodoro ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);
            var time_block_3 = session.get_nth_time_block (2);

            var now = Pomodoro.Timestamp.peek ();
            var session_changed_emitted = 0;
            var signals = new string[0];

            session_manager.current_time_block = time_block_2;
            assert_null (time_block_1.session);

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session.changed.connect (() => { session_changed_emitted++; });

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
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_3.get_completion_time ()),
                new GLib.Variant.int64 (session_manager.scheduler.calculate_time_block_completion_time (time_block_3))
            );

            assert_true (time_block_2.session == session);
            assert_true (time_block_3.session == session);

            assert_true (time_block_2.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (time_block_3.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_true (timer.is_started ());
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_advance_to_state__short_break ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1    = session.get_nth_time_block (0);

            var now = Pomodoro.Timestamp.peek ();
            // var changed_emitted = 0;
            var session_changed_emitted = 0;
            var signals = new string[0];

            // Start a pomodoro.
            session_manager.current_time_block = time_block_1;

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session.changed.connect (() => { session_changed_emitted++; });

            // Switch to a short-break.
            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.BREAK, now);

            var time_block_2 = session.get_next_time_block (time_block_1);
            assert_true (time_block_2.state == Pomodoro.State.SHORT_BREAK);
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
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.get_completion_time ()),
                new GLib.Variant.int64 (session_manager.scheduler.calculate_time_block_completion_time (time_block_2))
            );
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (time_block_2.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_true (timer.is_started ());
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);

            var cycle = session_manager.get_current_cycle ();
            assert_true (cycle.calculate_progress (now).is_nan ());
        }

        public void test_advance_to_state__undefined ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var session = new Pomodoro.Session.from_template (this.session_template);
            var time_block_1 = session.get_nth_time_block (0);
            var time_block_2 = session.get_nth_time_block (1);

            var signals = new string[0];

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
            session_manager.advance_to_state (Pomodoro.State.STOPPED, now);

            assert_true (session_manager.current_session == session);
            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (time_block_2.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED);
            assert_false (timer.is_started ());
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",  // TODO: is it correct?
                "resolve-state",
                "state-changed"
            });
        }

        public void test_advance_to_state__extend_pomodoro ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            session_manager.advance_to_state (Pomodoro.State.POMODORO, now);

            var time_block = session_manager.current_time_block;
            var expected_start_time = time_block.start_time;
            var expected_remaining_time = time_block.duration;
            var signals = new string[0];

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

            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.state == Pomodoro.State.POMODORO);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
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

        public void test_advance_to_state__extend_short_break ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK, now);

            var time_block = session_manager.current_time_block;
            var expected_start_time = time_block.start_time;
            var expected_remaining_time = time_block.duration;
            var signals = new string[0];

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK, now);

            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.state == Pomodoro.State.SHORT_BREAK);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
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

        public void test_advance_to_state__extend_long_break ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            session_manager.advance_to_state (Pomodoro.State.LONG_BREAK, now);

            var time_block = session_manager.current_time_block;
            var expected_start_time = time_block.start_time;
            var expected_remaining_time = time_block.duration;
            var signals = new string[0];

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.LONG_BREAK, now);

            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.state == Pomodoro.State.LONG_BREAK);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (expected_start_time)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
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

        /**
         * Expect to append new time-blocks when changing break states.
         */
        public void test_advance_to_state__switch_breaks ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            var signals = new string[0];

            // Start a short break.
            session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK, now);

            assert_true (session_manager.current_time_block.state == Pomodoro.State.SHORT_BREAK);
            assert_cmpint (session_manager.current_session.index (session_manager.current_time_block),
                           GLib.CompareOperator.EQ, 0);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_time_block.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.offset),
                new GLib.Variant.int64 (0)
            );

            // Switch to a long break.
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance_to_state (Pomodoro.State.LONG_BREAK, now);

            assert_true (session_manager.current_time_block.state == Pomodoro.State.LONG_BREAK);
            assert_cmpint (session_manager.current_session.index (session_manager.current_time_block),
                           GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_time_block.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (15 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.offset),
                new GLib.Variant.int64 (0)
            );
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });

            // Switch back to a short break.
            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            signals = {};
            session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK, now);

            assert_true (session_manager.current_time_block.state == Pomodoro.State.SHORT_BREAK);
            assert_cmpint (session_manager.current_session.index (session_manager.current_time_block),
                           GLib.CompareOperator.EQ, 0);
            assert_cmpvariant (
                new GLib.Variant.int64 (session_manager.current_time_block.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.duration),
                new GLib.Variant.int64 (5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.offset),
                new GLib.Variant.int64 (0)
            );
            assert_cmpstrv (signals, {
                "populated-session",  // TODO: it's questionable, the long break wasn't completed
                "leave-time-block",
                "leave-session",
                "rescheduled-session",
                "enter-session",
                "enter-time-block",
                "resolve-state",
                "state-changed"
            });
        }

        /**
         * Skipping to a pomodoro when the session is completed should start a new session.
         */
        public void test_advance_to_state__completed_session ()
        {
            // TODO
        }

        public void test_confirm_starting_break ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-break", true);

            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var time_block_1 = session_manager.current_time_block;

            var finished_time = session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (finished_time);
            timer.finish (finished_time);
            assert_true (timer.user_data == time_block_1);
            assert_true (timer.is_finished ());

            // Confirm after 1 minute.
            var activity_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance (activity_time);

            var time_block_2 = session_manager.current_time_block;
            assert_true (timer.user_data == time_block_2);
            assert_true (timer.is_started ());

            // Expect previous time-block to be extended by the inactivity time.
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.offset),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (activity_time)
            );
        }

        public void test_confirm_starting_pomodoro ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-pomodoro", true);

            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);

            var time_block_1 = session_manager.current_time_block;

            var finished_time = session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (finished_time);
            timer.finish (finished_time);
            assert_true (timer.user_data == time_block_1);
            assert_true (timer.is_finished ());

            // Confirm after 1 minute.
            var activity_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance (activity_time);

            var time_block_2 = session_manager.current_time_block;
            assert_true (time_block_2.state == Pomodoro.State.POMODORO);
            assert_true (timer.user_data == time_block_2);
            assert_true (timer.is_started ());

            // Expect previous time-block to be extended by the inactivity time.
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.offset),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (activity_time)
            );
        }


        /*
         * Tests for handling session expiry
         */

        public void test_reset ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);

            session_manager.current_session = session;

            var leave_session_emitted = 0;
            session_manager.leave_session.connect (() => {
                leave_session_emitted++;
            });

            var enter_session_emitted = 0;
            session_manager.enter_session.connect (() => {
                enter_session_emitted++;
            });

            // Reset should not do anything if session is scheduled.
            session_manager.reset ();
            assert_true (session_manager.current_session == session);

            session_manager.current_time_block = session.get_first_time_block ();
            session_manager.reset ();
            assert_true (session_manager.current_session != session);
            assert_cmpuint (leave_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (enter_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_null (session_manager.current_time_block);
        }

        /**
         * Check whether session expires after a timeout.
         *
         * In this test we manually set session `expiry-time`, which doesn't happen normally.
         */
        public void test_expire_session__after_timeout ()
        {
            Pomodoro.Timestamp.thaw ();

            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);
            var main_context    = GLib.MainContext.@default ();

            session_manager.current_session = session;
            session_manager.current_time_block = session.get_first_time_block ();

            var session_expired_emitted = 0;
            session_manager.session_expired.connect (() => {
                session_expired_emitted++;
            });

            var leave_session_emitted = 0;
            session_manager.leave_session.connect (() => {
                leave_session_emitted++;
            });

            var enter_session_emitted = 0;
            session_manager.enter_session.connect (() => {
                enter_session_emitted++;
            });

            var now = Pomodoro.Timestamp.from_now ();
            var elapsed = (uint) 0;
            var timeout_id = GLib.Timeout.add (100, () => {
                elapsed += 100;
                return GLib.Source.CONTINUE;
            });
            session.expiry_time = now + 500 * Pomodoro.Interval.MILLISECOND;

            while (elapsed < 2000)
            {
                main_context.iteration (true);

                if (session_expired_emitted > 0) {
                    break;
                }
            }

            GLib.Source.remove (timeout_id);

            assert_cmpuint (session_expired_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (leave_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_false (timer.is_started ());

            // Expect to a next session to be initialized.
            assert_cmpuint (enter_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_nonnull (session_manager.current_session);
            assert_true (session_manager.current_session.is_scheduled ());
        }

        /**
         * Check whether session expires after after a mock system suspend.
         */
        public void test_expire_session__after_suspend ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            timer.start ();

            var now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);
            assert_false (session_manager.current_session.is_scheduled ());

            var suspend_start = now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.suspending (suspend_start);

            var suspend_end = Pomodoro.Timestamp.advance (Pomodoro.SessionManager.SESSION_EXPIRY_TIMEOUT);
            timer.suspended (suspend_start, suspend_end);

            // Expect to a next session to be initialized.
            assert_nonnull (session_manager.current_session);
            assert_true (session_manager.current_session.is_scheduled ());
        }

        public void test_settings_change ()
        {
            var session_manager = new Pomodoro.SessionManager ();
            var signals         = new string[0];
            var sesssion        = this.create_session (session_manager);
            session_manager.current_session = sesssion;
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 10);
            settings.set_uint ("short-break-duration", 20);
            settings.set_uint ("long-break-duration", 30);
            settings.set_uint ("cycles", 3);

            assert_false (session_manager.has_uniform_breaks);

            // Expect reschedule to be applied at idle.
            assert_cmpstrv (signals, {});

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            var main_context = GLib.MainContext.@default ();
            while (main_context.iteration (false));

            assert_cmpvariant (
                session_manager.scheduler.session_template.to_variant (),
                Pomodoro.SessionTemplate.with_defaults ().to_variant ()
            );
            assert_cmpstrv (signals, {
                "rescheduled-session",
            });

            // Ensure reschedule done its job.
            var time_block_1 = sesssion.get_nth_time_block (0);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.get_intended_duration ()),
                new GLib.Variant.int64 (10 * Pomodoro.Interval.SECOND)
            );

            var time_block_2 = sesssion.get_nth_time_block (1);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.get_intended_duration ()),
                new GLib.Variant.int64 (20 * Pomodoro.Interval.SECOND)
            );

            // Check whether has-uniform-breaks gets updated
            settings.set_uint ("cycles", 1);
            assert_true (session_manager.has_uniform_breaks);
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

            this.add_test ("timer_reset__mark_as_uncompleted", this.test_timer_reset__mark_as_uncompleted);
            this.add_test ("timer_reset__mark_as_completed", this.test_timer_reset__mark_as_completed);
            this.add_test ("timer_reset__paused", this.test_timer_reset__paused);
            this.add_test ("timer_reset__completed_cycles", this.test_timer_reset__completed_cycles);
            this.add_test ("timer_reset__completed_session", this.test_timer_reset__completed_session);
            this.add_test ("timer_reset__extra_cycle", this.test_timer_reset__extra_cycle);
            this.add_test ("timer_reset__ignore_call", this.test_timer_reset__ignore_call);

            this.add_test ("timer_pause", this.test_timer_pause);
            this.add_test ("timer_resume", this.test_timer_resume);
            this.add_test ("timer_rewind", this.test_timer_rewind);
            this.add_test ("timer_rewind__multiple", this.test_timer_rewind__multiple);
            this.add_test ("timer_rewind__paused", this.test_timer_rewind__paused);
            this.add_test ("timer_rewind__paused_after_completion", this.test_timer_rewind__paused_after_completion);
            this.add_test ("timer_rewind__paused_multiple", this.test_timer_rewind__paused_multiple);

            this.add_test ("timer_finished__continuous", this.test_timer_finished__continuous);
            this.add_test ("timer_finished__wait_for_activity", this.test_timer_finished__wait_for_activity);
            this.add_test ("timer_finished__manual", this.test_timer_finished__manual);

            // this.add_test ("timer_suspended", this.test_timer_suspended);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);
            Pomodoro.Timestamp.set_auto_advance (Pomodoro.Interval.MICROSECOND);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);
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
                time_block_1.get_intended_duration (),
                new GLib.Variant.int64 (initial_duration)
            );
            assert_true (session_manager.current_time_block == time_block_1);
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_cmpstrv (signals, {
                "resolve-state",
                "rescheduled-session",
                "state-changed"
            });
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (time_block_1.start_time + expected_duration)
            );
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
            assert_cmpuint (session_manager.current_session.get_cycles ().length (), GLib.CompareOperator.EQ, session_template.cycles);
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
            assert_cmpfloat_with_epsilon (session_manager.current_time_block.get_weight (), 1.0, EPSILON);
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
         * Expect to start a new pomodoro when starting the timer again.
         */
        public void test_timer_start__continue_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now             = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var time_block_1 = session_manager.current_session.get_nth_time_block (0);
            var session      = time_block_1.session;
            var signals      = new string[0];

            // Stop the timer
            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);

            assert_nonnull (session_manager.current_session);
            assert_null (session_manager.current_time_block);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);

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
            assert_true (time_block_1.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_true (time_block_2.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
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
            var timer                 = new Pomodoro.Timer ();
            var session_manager       = new Pomodoro.SessionManager.with_timer (timer);

            var now                   = Pomodoro.Timestamp.peek ();
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

        public void test_timer_reset__mark_as_uncompleted ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var time_block = session_manager.current_time_block;
            var session    = session_manager.current_session;

            var session_changed_emitted = 0;
            var signals    = new string[0];

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session.changed.connect (() => { session_changed_emitted++; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);

            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);

            // `rescheduled-session` is necessary for session indicator to display the correct number of cycles.
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",
                "resolve-state",
                "state-changed",
            });
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_timer_reset__mark_as_completed ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var time_block = session_manager.current_time_block;
            var session    = session_manager.current_session;

            var session_changed_emitted = 0;
            var signals    = new string[0];

            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session.changed.connect (() => { session_changed_emitted++; });

            now = time_block.end_time - Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            timer.reset (now);

            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.COMPLETED);
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",
                "resolve-state",
                "state-changed",
            });
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Ensure that pausing the timer will not affect whether time-block will be marked as completed.
         */
        public void test_timer_reset__paused ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var time_block = session_manager.current_time_block;
            var completion_time = time_block.get_completion_time ();

            now = completion_time - Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            timer.pause (now);

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

            now = completion_time + Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            timer.reset (now);

            assert_null (session_manager.current_time_block);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (now)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);

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
            assert_cmpstrv (signals, {
                "leave-time-block",
                "rescheduled-session",
                "resolve-state",
                "state-changed",
            });
        }

        /**
         * Stopping a session with completed all cycles, but no long-break should not create new cycle at reset time.
         * Expect a new cycle to be added when starting the timer.
         */

        /**
         * Stopping a session with completed all cycles, but no long-break will cause reschedule and an extra cycle.
         * Expect a new cycle to be marked as hidden. We want to make it visible once resuming the timer.
         */
        public void test_timer_reset__completed_cycles ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);
            var session         = new Pomodoro.Session.from_template (this.session_template);
            var time_block      = session.get_last_time_block ();

            session.@foreach (
                (time_block) => {
                    time_block.set_completion_time (time_block.end_time);

                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            var now = time_block.start_time;
            Pomodoro.Timestamp.freeze_to (now);
            session_manager.current_time_block = time_block;

            var rescheduled_session_emitted = 0;
            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED);
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);

            // Expect extra cycle.
            var cycles = session.get_cycles ();
            assert_cmpuint (cycles.length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);
            assert_false (cycles.last ().data.is_visible ());
        }

        /**
         * Stopping a completed session including the long-break should mark session as ended.
         */
        public void test_timer_reset__completed_session ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.ensure_session ();

            var session = session_manager.current_session;
            var time_block = session.get_last_time_block ();

            session.@foreach (
                (time_block) => {
                    if (time_block.state != Pomodoro.State.LONG_BREAK) {
                        time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                    }
                }
            );

            Pomodoro.Timestamp.freeze_to (time_block.start_time);
            session_manager.current_time_block = time_block;

            var signals = new string[0];
            timer.resolve_state.connect (() => { signals += "resolve-state"; });
            timer.state_changed.connect (() => { signals += "state-changed"; });
            session_manager.enter_session.connect (() => { signals += "enter-session"; });
            session_manager.enter_time_block.connect (() => { signals += "enter-time-block"; });
            session_manager.leave_session.connect (() => { signals += "leave-session"; });
            session_manager.leave_time_block.connect (() => { signals += "leave-time-block"; });
            session_manager.scheduler.rescheduled_session.connect (() => { signals += "rescheduled-session"; });
            session_manager.scheduler.populated_session.connect (() => { signals += "populated-session"; });

            Pomodoro.Timestamp.freeze_to (time_block.end_time);
            timer.reset (time_block.end_time);

            assert_true (session_manager.current_session != session);
            assert_null (session_manager.current_session);
            assert_cmpstrv (signals, {
                "leave-time-block",
                "leave-session",
                "resolve-state",
                "state-changed"
            });
        }

        /**
         * Stopping an extra cycle should mark it as invisible - same as any cycle.
         */
        public void test_timer_reset__extra_cycle ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            session_manager.ensure_session ();

            var session = session_manager.current_session;
            session.@foreach (
                (time_block) => {
                    time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
                }
            );

            var time_block = session.get_last_time_block ();
            time_block.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);

            var now = time_block.start_time;
            Pomodoro.Timestamp.freeze_to (now);
            session_manager.current_time_block = time_block;

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            session_manager.advance (now);

            time_block = session_manager.current_time_block;
            assert_nonnull (time_block);
            assert_true (time_block.state == Pomodoro.State.POMODORO);
            assert_true (time_block.get_is_extra ());

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            timer.reset (now);

            var cycles = session.get_cycles ();
            assert_cmpuint (cycles.length (), GLib.CompareOperator.EQ, this.session_template.cycles + 1);
            assert_false (cycles.last ().data.is_visible ());
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
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

            // var signals         = new string[0];  // TODO

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var session = session_manager.current_session;
            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();

            var session_changed_emitted = 0;
            session.changed.connect (() => { session_changed_emitted++; });

            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            var expected_gap_start_time = now;
            var expected_cycle_progress = cycle.calculate_progress (now);
            timer.pause (now);
            assert_true (timer.is_paused ());

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
                new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_true (cycle.is_visible ());
            assert_cmpuint (session.get_cycles ().length (),
                            GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), expected_cycle_progress, EPSILON);
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 0);  // reschedule once resuming
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);

            // Pause after the completion_time.
            timer.resume (now);

            now = time_block.get_completion_time () + Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            timer.pause (now);
            assert_true (cycle.is_visible ());
            assert_cmpuint (session.get_cycles ().length (),
                            GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 1.0, EPSILON);
        }

        public void test_timer_resume ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            // var signals         = new string[0];  // TODO

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var session = session_manager.current_session;
            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();

            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;
            var session_changed_emitted = 0;

            now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);

            var expected_time_block_start_time = time_block.start_time;
            var expected_time_block_end_time = time_block.end_time + Pomodoro.Interval.MINUTE;
            var expected_gap_start_time = now;
            var expected_gap_end_time = now + Pomodoro.Interval.MINUTE;
            var expected_cycle_progress = cycle.calculate_progress (now);

            timer.pause (now);
            assert_true (timer.is_paused ());

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });
            session.changed.connect (() => { session_changed_emitted++; });

            now = expected_gap_end_time;
            Pomodoro.Timestamp.freeze_to (now);
            timer.resume (now);
            assert_false (timer.is_paused ());
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (session_manager.scheduler.calculate_time_block_completion_time (time_block))
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
                new GLib.Variant.int64 (expected_gap_end_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (expected_time_block_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (expected_time_block_end_time)
            );
            assert_true (cycle.is_visible ());
            assert_cmpuint (session.get_cycles ().length (),
                            GLib.CompareOperator.EQ, this.session_template.cycles);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), expected_cycle_progress, EPSILON);
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (session_changed_emitted, GLib.CompareOperator.EQ, 1);
        }

        public void test_timer_rewind ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            // var signals         = new string[0];  // TODO

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);

            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var rescheduled_session_emitted = 0;

            var expected_time_block_start_time = time_block.start_time;
            var expected_time_block_end_time = time_block.end_time + Pomodoro.Interval.MINUTE;
            var expected_time_block_completion_time = time_block.get_completion_time () + Pomodoro.Interval.MINUTE;
            var expected_gap_end_time = now;
            var expected_gap_start_time = expected_gap_end_time - Pomodoro.Interval.MINUTE;
            var expected_cycle_progress = cycle.calculate_progress (expected_gap_start_time);

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_false (timer.is_paused ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (expected_time_block_completion_time)
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
                new GLib.Variant.int64 (expected_gap_end_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.start_time),
                new GLib.Variant.int64 (expected_time_block_start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.end_time),
                new GLib.Variant.int64 (expected_time_block_end_time)
            );
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), expected_cycle_progress, EPSILON);
            assert_cmpuint (rescheduled_session_emitted, GLib.CompareOperator.EQ, 1);
        }

        /**
         * Use rewind several times.
         *
         * When gaps overlay, expect them to be merged.
         */
        public void test_timer_rewind__multiple ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;

            // First rewind.
            now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);

            timer.rewind (Pomodoro.Interval.MINUTE, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE)
            );
            time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (time_block.start_time + 2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 0.1, EPSILON);

            // Second rewind.
            gaps_count = 0;
            gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.SECOND);

            timer.rewind (Pomodoro.Interval.MINUTE, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (65 * Pomodoro.Interval.SECOND)
            );
            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (time_block.start_time + 65 * Pomodoro.Interval.SECOND)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (time_block.end_time - 5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 65.0 / 1200.0, EPSILON);

            // Third rewind.
            gaps_count = 0;
            gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.SECOND);

            timer.rewind (5 * Pomodoro.Interval.MINUTE, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );
            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 1);
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_start_time),
                new GLib.Variant.int64 (time_block.start_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (gap_end_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (time_block.end_time - 5 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 0.0, EPSILON);
        }

        public void test_timer_rewind__paused ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            timer.pause (now);

            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();
            var gaps_count = (uint) 0;
            var rescheduled_session_emitted = 0;

            var expected_completion_time = time_block.get_completion_time () + Pomodoro.Interval.MINUTE;

            session_manager.scheduler.rescheduled_session.connect (() => { rescheduled_session_emitted++; });

            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.SECOND);

            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_true (timer.is_paused ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (4 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (expected_completion_time)
            );

            time_block.foreach_gap ((gap) => {
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 2);
            assert_cmpvariant (
                new GLib.Variant.int64 (cycle.get_completion_time ()),
                new GLib.Variant.int64 (expected_completion_time)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (timer.state.paused_time), 4.0 / 20.0, EPSILON);
            assert_cmpfloat_with_epsilon (cycle.get_weight (), 1.0, EPSILON);
            assert_true (cycle.is_visible ());
        }

        public void test_timer_rewind__paused_after_completion ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            now = Pomodoro.Timestamp.advance (22 * Pomodoro.Interval.MINUTE);
            timer.pause (now);

            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();
            var expected_completion_time = time_block.get_completion_time ();

            // First rewind.
            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.SECOND);

            timer.rewind (Pomodoro.Interval.MINUTE, now);
            assert_true (timer.is_paused ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (21 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (expected_completion_time)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 1.0, EPSILON);
            assert_cmpfloat_with_epsilon (cycle.get_weight (), 1.0, EPSILON);
            assert_true (cycle.is_visible ());

            // Second rewind.
            timer.rewind (25 * Pomodoro.Interval.MINUTE, now);
            assert_true (timer.is_paused ());
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 0.0 / 20.0, EPSILON);
            assert_cmpfloat_with_epsilon (cycle.get_weight (), 1.0, EPSILON);
            assert_true (cycle.is_visible ());
        }

        public void test_timer_rewind__paused_multiple ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var now = Pomodoro.Timestamp.peek ();
            timer.start (now);

            now = Pomodoro.Timestamp.advance (3 * Pomodoro.Interval.MINUTE);
            timer.pause (now);

            var time_block = session_manager.current_time_block;
            var cycle = session_manager.get_current_cycle ();
            var gaps_count = (uint) 0;
            var gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            var gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            var original_completion_time = time_block.get_completion_time ();

            // First rewind.
            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.SECOND);

            timer.rewind (Pomodoro.Interval.MINUTE, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (2 * Pomodoro.Interval.MINUTE)
            );
            time_block.foreach_gap ((gap) => {
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 2);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (original_completion_time + Pomodoro.Interval.MINUTE)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (timer.state.paused_time), 2.0 / 20.0, EPSILON);
            assert_cmpfloat_with_epsilon (cycle.get_weight (), 1.0, EPSILON);
            assert_true (cycle.is_visible ());

            // Second rewind.
            gaps_count = 0;
            gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            now = Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.SECOND);

            timer.rewind (Pomodoro.Interval.MINUTE, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (Pomodoro.Interval.MINUTE)
            );
            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpuint (gaps_count, GLib.CompareOperator.EQ, 2);
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (original_completion_time + 2 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 1.0 / 20.0, EPSILON);
            assert_cmpfloat_with_epsilon (cycle.get_weight (), 1.0, EPSILON);
            assert_true (cycle.is_visible ());

            // Third rewind.
            gaps_count = 0;
            gap_start_time = Pomodoro.Timestamp.UNDEFINED;
            gap_end_time = Pomodoro.Timestamp.UNDEFINED;
            now = Pomodoro.Timestamp.advance (45 * Pomodoro.Interval.MINUTE);

            timer.rewind (5 * Pomodoro.Interval.MINUTE, now);

            assert_cmpvariant (
                new GLib.Variant.int64 (timer.calculate_elapsed (now)),
                new GLib.Variant.int64 (0)
            );
            assert_true (session_manager.current_time_block == time_block);
            assert_true (time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.foreach_gap ((gap) => {
                gap_start_time = gap.start_time;
                gap_end_time = gap.end_time;
                gaps_count++;
            });
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block.get_completion_time ()),
                new GLib.Variant.int64 (original_completion_time + 3 * Pomodoro.Interval.MINUTE)
            );
            assert_cmpfloat_with_epsilon (cycle.calculate_progress (now), 0.0, EPSILON);
            assert_cmpfloat_with_epsilon (cycle.get_weight (), 1.0, EPSILON);
            assert_true (cycle.is_visible ());
        }

        public void test_timer_finished__continuous ()
        {
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            timer.start ();

            var state_changed_call_count = 0;
            var finished_call_count = 0;
            var state_1 = Pomodoro.TimerState ();
            var state_2 = Pomodoro.TimerState ();

            timer.finished.connect (() => {
                finished_call_count++;
            });

            timer.state_changed.connect ((current_state, previous_state) => {
                if (state_changed_call_count == 0) {
                    state_1 = current_state;
                }

                if (state_changed_call_count == 1) {
                    assert_true (previous_state.equals (state_1));
                    state_2 = current_state;
                }

                state_changed_call_count++;
            });

            var finished_time = session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (finished_time);
            timer.finish (finished_time);

            assert_cmpuint (state_changed_call_count, GLib.CompareOperator.EQ, 2);
            assert_cmpuint (finished_call_count, GLib.CompareOperator.EQ, 1);

            assert_true (state_1.is_finished ());
            assert_false (state_2.is_finished ());

            assert_cmpvariant (
                new GLib.Variant.int64 (state_1.finished_time),
                new GLib.Variant.int64 (finished_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (state_2.started_time),
                new GLib.Variant.int64 (finished_time)
            );
        }

        public void test_timer_finished__wait_for_activity ()
        {
            var idle_monitor    = new Pomodoro.IdleMonitor.dummy ();
            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            assert_true (idle_monitor.provider is Pomodoro.DummyIdleMonitorProvider);

            session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);

            var time_block_1 = session_manager.current_time_block;

            var finished_time = session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (finished_time);
            timer.finish (finished_time);

            var time_block_2 = session_manager.current_time_block;
            assert_true (time_block_2.state == Pomodoro.State.POMODORO);
            assert_true (timer.user_data == time_block_2);
            assert_false (timer.is_started ());

            // Simulate inactivity of 1 minute.
            var activity_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            idle_monitor.provider.became_active ();

            assert_true (session_manager.current_time_block == time_block_2);
            assert_true (timer.user_data == time_block_2);
            assert_true (timer.is_started ());

            // Expect previous time-block to be extended by the inactivity time.
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.offset),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (activity_time)
            );
        }

        public void test_timer_finished__manual ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-break", true);
            settings.set_boolean ("confirm-starting-pomodoro", true);

            var timer           = new Pomodoro.Timer ();
            var session_manager = new Pomodoro.SessionManager.with_timer (timer);

            var confirm_advancement_call_count = 0;
            session_manager.confirm_advancement.connect (() => {
                confirm_advancement_call_count++;
            });

            timer.start ();

            var time_block_1 = session_manager.current_time_block;

            var finished_time = session_manager.current_time_block.end_time;
            Pomodoro.Timestamp.freeze_to (finished_time);
            timer.finish (finished_time);
            assert_true (time_block_1.state == Pomodoro.State.POMODORO);
            assert_true (timer.state.is_finished ());

            // Confirm after 1 minute.
            var activity_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            // Note that timer.start() can't be used interchangeably with session_manager.advance(),
            // as the timer has already started.
            session_manager.advance (activity_time);

            var time_block_2 = session_manager.current_time_block;
            assert_true (time_block_2.state.is_break ());
            assert_true (timer.user_data == time_block_2);
            assert_true (timer.is_started ());

            // Expect previous time-block to be extended by the inactivity time.
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.started_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (timer.state.offset),
                new GLib.Variant.int64 (0)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_1.end_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (time_block_2.start_time),
                new GLib.Variant.int64 (activity_time)
            );
            assert_cmpuint (confirm_advancement_call_count, GLib.CompareOperator.EQ, 1);
        }
    }


    public class SessionManagerDatabaseTest : Tests.TestSuite
    {
        private Pomodoro.Timer?           timer;
        private Pomodoro.SessionManager?  session_manager;
        private Pomodoro.TimezoneHistory? timezone_history;
        private GLib.TimeZone?            new_york_timezone;
        private GLib.TimeZone?            london_timezone;
        private GLib.MainLoop?            main_loop;
        private uint                      timeout_id = 0;

        public SessionManagerDatabaseTest ()
        {
            this.add_test ("save__ensure_session", this.test_save__ensure_session);
            this.add_test ("save__update_status", this.test_save__update_status);
            this.add_test ("save__update_time_range", this.test_save__update_time_range);
            this.add_test ("save__delete_extra_time_blocks", this.test_save__delete_extra_time_blocks);
            this.add_test ("save__delete_extra_gaps", this.test_save__delete_extra_gaps);
            this.add_test ("save__delete_empty_session", this.test_save__delete_empty_session);
            this.add_test ("save__advance_session", this.test_save__advance_session);
            this.add_test ("save__timer_start", this.test_save__timer_start);
            this.add_test ("save__timer_pause", this.test_save__timer_pause);
            this.add_test ("save__timer_rewind", this.test_save__timer_rewind);
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze_to (2000000000 * Pomodoro.Interval.SECOND);
            Pomodoro.Timestamp.set_auto_advance (Pomodoro.Interval.MICROSECOND);

            var settings = Pomodoro.get_settings ();
            settings.set_uint ("pomodoro-duration", 1500);
            settings.set_uint ("short-break-duration", 300);
            settings.set_uint ("long-break-duration", 900);
            settings.set_uint ("cycles", 4);
            settings.set_boolean ("confirm-starting-break", false);
            settings.set_boolean ("confirm-starting-pomodoro", false);

            Pomodoro.Database.open ();

            try {
                this.new_york_timezone = new GLib.TimeZone.identifier ("America/New_York");
                this.london_timezone = new GLib.TimeZone.identifier ("Europe/London");
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            this.main_loop = new GLib.MainLoop ();

            this.timezone_history = new Pomodoro.TimezoneHistory ();
            this.timezone_history.insert (Pomodoro.Timestamp.peek (), this.new_york_timezone);

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

            this.session_manager = new Pomodoro.SessionManager.with_timer (this.timer);
        }

        public override void teardown ()
        {
            var settings = Pomodoro.get_settings ();
            settings.revert ();

            this.timer.reset ();
            Pomodoro.Timer.set_default (null);

            this.session_manager = null;
            this.timer = null;
            this.timezone_history = null;
            this.main_loop = null;

            Pomodoro.Database.close ();
        }

        private bool run_main_loop (uint timeout = 1000)
        {
            var success = true;

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.timeout_id = GLib.Timeout.add (timeout, () => {
                this.timeout_id = 0;
                this.main_loop.quit ();

                success = false;

                return GLib.Source.REMOVE;
            });

            this.main_loop.run ();

            return success;
        }

        private void quit_main_loop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.main_loop.quit ();
        }

        private void run_save ()
        {
            this.session_manager.save.begin (
                (obj, res) => {
                    assert_true (this.session_manager.save.end (res));

                    this.quit_main_loop ();
                });

            assert_true (this.run_main_loop ());
        }

        /**
         * After `ensure_session()` no time-block is in-progress, so expect nothing to be saved.
         */
        public void test_save__ensure_session ()
        {
            this.session_manager.ensure_session ();
            this.run_save ();

            var repository = Pomodoro.Database.get_repository ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__update_status ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.session_manager.current_session = session;
            this.run_save ();

            Pomodoro.SessionEntry? initial_session_entry = null;
            Pomodoro.TimeBlockEntry? initial_time_block_entry = null;

            try {
                initial_session_entry = (Pomodoro.SessionEntry?) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_nonnull (initial_session_entry);

                initial_time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_nonnull (initial_time_block_entry);

                // Modify just the time-block status, expect its entry to be updated.
                time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            this.run_save ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var session_entry = (Pomodoro.SessionEntry?) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (session_entry.id),
                    new GLib.Variant.int64 (initial_session_entry.id)
                );

                var time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.id),
                    new GLib.Variant.int64 (initial_time_block_entry.id)
                );
                assert_cmpstr (time_block_entry.status,
                               GLib.CompareOperator.EQ,
                               "completed");
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__update_time_range ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.session_manager.current_session = session;
            this.run_save ();

            Pomodoro.SessionEntry? initial_session_entry = null;
            Pomodoro.TimeBlockEntry? initial_time_block_entry = null;

            try {
                initial_session_entry = (Pomodoro.SessionEntry?) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_nonnull (initial_session_entry);

                initial_time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_nonnull (initial_time_block_entry);

                // Modify just the time-block range, expect its entries to be updated.
                time_block.move_by (Pomodoro.Interval.MINUTE);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            this.run_save ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var session_entry = (Pomodoro.SessionEntry?) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (session_entry.id),
                    new GLib.Variant.int64 (initial_session_entry.id)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (session_entry.start_time),
                    new GLib.Variant.int64 (session.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (session_entry.end_time),
                    new GLib.Variant.int64 (session.end_time)
                );

                var time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.id),
                    new GLib.Variant.int64 (initial_time_block_entry.id)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.start_time),
                    new GLib.Variant.int64 (time_block.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.end_time),
                    new GLib.Variant.int64 (time_block.end_time)
                );
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Simulate a hypothetical scenario that time-block exists in database but not in
         * session. Expect it to be removed.
         *
         * At the time this test is written we do not save scheduled time-blocks and we
         * don't remove time-blocks from session once they have started.
         */
        public void test_save__delete_extra_time_blocks ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.session_manager.current_session = session;
            this.run_save ();

            Pomodoro.SessionEntry? session_entry = null;
            Pomodoro.TimeBlockEntry? time_block_entry = null;

            try {
                session_entry = (Pomodoro.SessionEntry?) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_nonnull (session_entry);

                time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_nonnull (time_block_entry);

                var extra_time_block_entry = new Pomodoro.TimeBlockEntry ();
                extra_time_block_entry.repository = repository;
                extra_time_block_entry.session_id = session_entry.id;
                extra_time_block_entry.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
                extra_time_block_entry.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
                extra_time_block_entry.state = "pomodoro";
                extra_time_block_entry.status = "uncompleted";
                extra_time_block_entry.intended_duration = 0;
                extra_time_block_entry.save_sync ();

                var results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            this.run_save ();

            try {
                var results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var remaining_time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (remaining_time_block_entry.id),
                    new GLib.Variant.int64 (time_block_entry.id)
                );
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__delete_extra_gaps ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var gap = new Pomodoro.Gap ();
            gap.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            gap.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.start_time = gap.start_time;
            time_block.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);
            time_block.add_gap (gap);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.session_manager.current_session = session;
            this.run_save ();

            Pomodoro.SessionEntry? session_entry = null;
            Pomodoro.TimeBlockEntry? time_block_entry = null;
            Pomodoro.GapEntry? gap_entry = null;

            try {
                session_entry = (Pomodoro.SessionEntry?) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_nonnull (session_entry);

                time_block_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_nonnull (time_block_entry);

                gap_entry = (Pomodoro.GapEntry?) repository.find_one_sync (
                        typeof (Pomodoro.GapEntry), null);
                assert_nonnull (gap_entry);

                var extra_gap_entry = new Pomodoro.GapEntry ();
                extra_gap_entry.repository = repository;
                extra_gap_entry.time_block_id = time_block_entry.id;
                extra_gap_entry.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
                extra_gap_entry.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
                extra_gap_entry.save_sync ();

                var results = repository.find_sync (typeof (Pomodoro.GapEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            // Only changed time-block will be saved. Force it.
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            this.run_save ();

            try {

                var results = repository.find_sync (typeof (Pomodoro.GapEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var remaining_gap_entry = (Pomodoro.TimeBlockEntry?) repository.find_one_sync (
                        typeof (Pomodoro.GapEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (remaining_gap_entry.id),
                    new GLib.Variant.int64 (gap_entry.id)
                );
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * If session becomes empty, expect database entry to be removed.
         *
         * It's a hypothetical scenario in practice.
         */
        public void test_save__delete_empty_session ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var session = new Pomodoro.Session ();
            session.append (time_block);

            this.session_manager.current_session = session;
            assert_false (this.timer.is_running ());

            this.run_save ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            time_block.set_status (Pomodoro.TimeBlockStatus.SCHEDULED);
            this.run_save ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 0);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);
            this.run_save ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__advance_session ()
        {
            var repository = Pomodoro.Database.get_repository ();

            var time_block_1 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_1.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block_1.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block_1.set_status (Pomodoro.TimeBlockStatus.UNCOMPLETED);

            var time_block_2 = new Pomodoro.TimeBlock (Pomodoro.State.POMODORO);
            time_block_2.start_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block_2.end_time = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            time_block_2.set_status (Pomodoro.TimeBlockStatus.IN_PROGRESS);

            var session_1 = new Pomodoro.Session ();
            session_1.append (time_block_1);

            var session_2 = new Pomodoro.Session ();
            session_2.append (time_block_2);

            this.session_manager.current_session = session_1;
            this.session_manager.current_session = session_2;
            this.run_save ();

            // Ensure that previous session has been saved as well as the current one.
            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 2);
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__timer_start ()
        {
            this.session_manager.timer.start ();
            this.run_save ();

            // Expect one time-block that is in-progress to be saved.
            var repository = Pomodoro.Database.get_repository ();
            var session    = this.session_manager.current_session;
            var time_block = this.session_manager.current_time_block;

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.SessionEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var session_entry = (Pomodoro.SessionEntry) repository.find_one_sync (
                        typeof (Pomodoro.SessionEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (session_entry.start_time),
                    new GLib.Variant.int64 (session.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (session_entry.end_time),
                    new GLib.Variant.int64 (session.end_time)
                );

                var time_block_entry = (Pomodoro.TimeBlockEntry) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.start_time),
                    new GLib.Variant.int64 (time_block.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.end_time),
                    new GLib.Variant.int64 (time_block.end_time)
                );
                assert_cmpstr (time_block_entry.status,
                               GLib.CompareOperator.EQ,
                               "in-progress");
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        public void test_save__timer_pause ()
        {
            var repository = Pomodoro.Database.get_repository ();

            this.timer.start ();
            this.run_save ();

            // Pause timer
            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.timer.pause ();
            this.run_save ();

            var session = this.session_manager.current_session;
            assert_false (Pomodoro.Timestamp.is_undefined (session.end_time));

            var time_block = this.session_manager.current_time_block;
            assert_false (Pomodoro.Timestamp.is_undefined (time_block.end_time));

            var gap = time_block.get_last_gap ();
            assert_true (Pomodoro.Timestamp.is_undefined (gap.end_time));

            var expected_time_block_id = (int64) 0;
            var expected_gap_id = (int64) 0;

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.GapEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var time_block_entry = (Pomodoro.TimeBlockEntry) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.end_time),
                    new GLib.Variant.int64 (time_block.end_time)
                );

                var gap_entry = (Pomodoro.GapEntry) repository.find_one_sync (
                        typeof (Pomodoro.GapEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.time_block_id),
                    new GLib.Variant.int64 (time_block_entry.id)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.start_time),
                    new GLib.Variant.int64 (gap.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.end_time),
                    new GLib.Variant.int64 (gap.end_time)
                );

                expected_time_block_id = time_block_entry.id;
                expected_gap_id = gap_entry.id;
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }

            // Resume timer
            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.timer.resume ();
            assert_true (Pomodoro.Timestamp.is_defined (gap.end_time));

            this.run_save ();

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.GapEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var time_block_entry = (Pomodoro.TimeBlockEntry) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.id),
                    new GLib.Variant.int64 (expected_time_block_id)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.end_time),
                    new GLib.Variant.int64 (time_block.end_time)
                );

                var gap_entry = (Pomodoro.GapEntry) repository.find_one_sync (
                        typeof (Pomodoro.GapEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.id),
                    new GLib.Variant.int64 (expected_gap_id)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.time_block_id),
                    new GLib.Variant.int64 (time_block_entry.id)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.start_time),
                    new GLib.Variant.int64 (gap.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.end_time),
                    new GLib.Variant.int64 (gap.end_time)
                );
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        /**
         * Gaps may be normalized after using rewind. Expect unnecessary gaps to be removed.
         */
        public void test_save__timer_rewind ()
        {
            var repository = Pomodoro.Database.get_repository ();

            this.timer.start ();

            var now = Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.timer.pause (now);

            now = now + Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            this.timer.resume (now);
            this.run_save ();

            now = now + Pomodoro.Interval.MINUTE;
            Pomodoro.Timestamp.freeze_to (now);
            this.timer.rewind (3 * Pomodoro.Interval.MINUTE, now);
            this.run_save ();

            var time_block = this.session_manager.current_time_block;
            var gap = time_block.get_last_gap ();
            assert_cmpvariant (
                new GLib.Variant.int64 (gap.duration),
                new GLib.Variant.int64 (3 * Pomodoro.Interval.MINUTE + Pomodoro.Interval.MICROSECOND)  // FIXME: where the one microsecond came from?
            );

            try {
                Gom.ResourceGroup results;

                results = repository.find_sync (typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                results = repository.find_sync (typeof (Pomodoro.GapEntry), null);
                assert_cmpuint (results.count, GLib.CompareOperator.EQ, 1);

                var time_block_entry = (Pomodoro.TimeBlockEntry) repository.find_one_sync (
                        typeof (Pomodoro.TimeBlockEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.start_time),
                    new GLib.Variant.int64 (time_block.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (time_block_entry.end_time),
                    new GLib.Variant.int64 (time_block.end_time)
                );

                var gap_entry = (Pomodoro.GapEntry) repository.find_one_sync (
                        typeof (Pomodoro.GapEntry), null);
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.start_time),
                    new GLib.Variant.int64 (gap.start_time)
                );
                assert_cmpvariant (
                    new GLib.Variant.int64 (gap_entry.end_time),
                    new GLib.Variant.int64 (gap.end_time)
                );
            }
            catch (GLib.Error error) {
                assert_no_error (error);
            }
        }

        // TODO: test restore
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionManagerTest (),
        new Tests.SessionManagerTimerTest (),
        new Tests.SessionManagerDatabaseTest ()
    );
}
