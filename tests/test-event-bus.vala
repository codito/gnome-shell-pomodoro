namespace Tests
{
    public class EventBusTest : Tests.TestSuite
    {
        private Pomodoro.Timer                     timer;
        private Pomodoro.SessionManager            session_manager;
        private Pomodoro.EventProducer             producer;
        private Pomodoro.EventBus                  bus;
        private Pomodoro.SessionManagerActionGroup session_manager_action_group;
        private Pomodoro.TimerActionGroup          timer_action_group;

        public EventBusTest ()
        {
            this.add_test ("add_event_watch__start", this.test_add_event_watch__start);
            this.add_test ("add_event_watch__pause", this.test_add_event_watch__pause);
            this.add_test ("add_event_watch__with_condition", this.test_add_event_watch__with_condition);
            this.add_test ("remove_event_watch", this.test_remove_event_watch);

            this.add_test ("add_condition_watch", this.test_add_condition_watch);
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

            this.timer = new Pomodoro.Timer ();
            Pomodoro.Timer.set_default (this.timer);

            this.session_manager = new Pomodoro.SessionManager.with_timer (this.timer);
            Pomodoro.SessionManager.set_default (this.session_manager);

            this.session_manager_action_group = new Pomodoro.SessionManagerActionGroup ();
            assert (this.session_manager_action_group.session_manager == this.session_manager);

            this.timer_action_group = new Pomodoro.TimerActionGroup ();
            assert (this.timer_action_group.timer == this.timer);

            this.producer = new Pomodoro.EventProducer ();
            assert (producer.session_manager == this.session_manager);
            assert (producer.timer == this.timer);

            this.bus = this.producer.bus;
        }

        public override void teardown ()
        {
            this.producer = null;
            this.bus = null;
            this.session_manager = null;
            this.timer = null;

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);

            Pomodoro.Context.unset_event_source ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        /*
         * Events
         */

        public void test_add_event_watch__start ()
        {
            var expected_timestamp = Pomodoro.Timestamp.from_now ();
            var event_triggered_count = 0;

            this.bus.add_event_watch ("start", null, (event) => {
                event_triggered_count++;

                assert_cmpvariant (
                    new GLib.Variant.int64 (event.context.timestamp),
                    new GLib.Variant.int64 (expected_timestamp)
                );
            });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("start", null);

            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_add_event_watch__pause ()
        {
            this.timer.start ();

            var expected_timestamp = Pomodoro.Timestamp.from_now ();
            var event_triggered_count = 0;

            this.bus.add_event_watch ("pause", null, (event) => {
                event_triggered_count++;

                assert_cmpvariant (
                    new GLib.Variant.int64 (event.context.timestamp),
                    new GLib.Variant.int64 (expected_timestamp)
                );
            });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("pause", null);

            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_add_event_watch__with_condition ()
        {
            var condition = new Pomodoro.Comparison (
                new Pomodoro.Variable ("state"),
                Pomodoro.Operator.EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.BREAK))
            );
            var event_triggered_count = 0;

            this.bus.add_event_watch ("pause", condition, (event) => {
                event_triggered_count++;

                assert_true (event.context.timer_state.is_paused ());
            });

            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            // Make condition unmet.
            this.timer_action_group.activate_action ("pause", null);
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 0);

            // Make condition met.
            this.session_manager_action_group.activate_action ("advance", null);
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 0);
            assert_false (this.timer.is_paused ());

            this.timer_action_group.activate_action ("pause", null);
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_remove_event_watch ()
        {
            var expected_refcount = this.ref_count;

            var event_triggered_count = 0;
            var watch_id = this.bus.add_event_watch ("start", null, (event) => {
                event_triggered_count++;
            });

            this.bus.remove_event_watch (watch_id);

            this.timer.start ();
            assert_cmpuint (event_triggered_count, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (this.ref_count, GLib.CompareOperator.EQ, expected_refcount);
        }

        /*
         * Conditions
         */

        public void test_add_condition_watch ()
        {
            var start_timestamp = Pomodoro.Timestamp.peek ();
            var pause_timestamp = start_timestamp + Pomodoro.Interval.MINUTE;
            var stop_timestamp = pause_timestamp + Pomodoro.Interval.MINUTE;
            var signals = new string[0];
            var paused_called = false;
            var resumed_called = false;

            this.bus.add_condition_watch (
                    new Pomodoro.Comparison.is_true (new Pomodoro.Variable ("is-started")),
                    (context) => {
                        signals += "enter-condition";

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (start_timestamp)
                        );
                    },
                    (context) => {
                        signals += "leave-condition";

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (stop_timestamp)
                        );
                    });

            this.bus.add_condition_watch (
                    new Pomodoro.Comparison.is_true (new Pomodoro.Variable ("is-paused")),
                    (context) => {
                        paused_called = true;

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (pause_timestamp)
                        );
                    },
                    (context) => {
                        resumed_called = true;

                        assert_cmpvariant (
                            new GLib.Variant.int64 (context.timestamp),
                            new GLib.Variant.int64 (stop_timestamp)
                        );
                    });

            Pomodoro.Timestamp.freeze_to (start_timestamp);
            this.timer.start ();

            Pomodoro.Timestamp.freeze_to (pause_timestamp);
            this.timer.pause ();

            Pomodoro.Timestamp.freeze_to (stop_timestamp);
            this.timer.reset ();

            assert_cmpstrv (signals, {
                "enter-condition",
                "leave-condition"
            });
            assert_true (paused_called);
            assert_true (resumed_called);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.EventBusTest ()
    );
}
