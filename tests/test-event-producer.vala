namespace Tests
{
    public class EventProducerTest : Tests.TestSuite
    {
        private Pomodoro.Timer                     timer;
        private Pomodoro.SessionManager            session_manager;
        private Pomodoro.EventProducer             producer;
        private Pomodoro.SessionManagerActionGroup session_manager_action_group;
        private Pomodoro.TimerActionGroup          timer_action_group;

        public EventProducerTest ()
        {
            this.add_test ("timer_start", this.test_timer_start);
            this.add_test ("timer_reset", this.test_timer_reset);
            this.add_test ("timer_reset__paused", this.test_timer_reset__paused);
            this.add_test ("timer_pause", this.test_timer_pause);
            this.add_test ("timer_resume", this.test_timer_resume);
            this.add_test ("timer_rewind", this.test_timer_rewind);
            this.add_test ("timer_finished__continuous", this.test_timer_finished__continuous);
            this.add_test ("timer_finished__wait_for_activity", this.test_timer_finished__wait_for_activity);
            this.add_test ("timer_finished__manual", this.test_timer_finished__manual);

            this.add_test ("session_manager_advance__uncompleted", this.test_session_manager_advance__uncompleted);
            this.add_test ("session_manager_advance__completed", this.test_session_manager_advance__completed);
            this.add_test ("session_manager_advance__paused", this.test_session_manager_advance__paused);
            this.add_test ("session_manager_confirm_advancement", this.test_session_manager_confirm_advancement);
            this.add_test ("session_manager_session_expired", this.test_session_manager_session_expired);
            this.add_test ("session_manager_reset", this.test_session_manager_reset);
            this.add_test ("session_manager_ensure_session", this.test_session_manager_ensure_session);
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

            this.producer = new Pomodoro.EventProducer ();
            assert (producer.session_manager == this.session_manager);
            assert (producer.timer == this.timer);

            this.session_manager_action_group = new Pomodoro.SessionManagerActionGroup ();
            assert (this.session_manager_action_group.session_manager == this.session_manager);

            this.timer_action_group = new Pomodoro.TimerActionGroup ();
            assert (this.timer_action_group.timer == this.timer);
        }

        public override void teardown ()
        {
            this.producer = null;
            this.session_manager_action_group = null;
            this.timer_action_group = null;

            Pomodoro.SessionManager.set_default (null);
            Pomodoro.Timer.set_default (null);

            Pomodoro.Context.unset_event_source ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        /*
         * Timer
         */

        public void test_timer_start ()
        {
            this.session_manager.ensure_session ();

            var time_block = this.session_manager.current_session.get_first_time_block ();

            var expected_timestamp = Pomodoro.Timestamp.from_now ();
            var expected_state = Pomodoro.TimerState () {
                duration = time_block.duration,
                started_time = expected_timestamp,
                user_data = (void*) time_block
            };
            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    GLib.debug ("Event '%s'\n%s", event.spec.name, event.context.timer_state.to_representation ());

                    event_names += event.spec.name;

                    assert_cmpvariant (
                        event.context.timer_state.to_variant (),
                        expected_state.to_variant ()
                    );
                    assert_nonnull (event.context.time_block);
                    assert_true (event.context.time_block.state == Pomodoro.State.POMODORO);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("start", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "start",
                "change",
            });
        }

        public void test_timer_reset ()
        {
            this.timer.start ();

            var expected_timestamp = Pomodoro.Timestamp.from_now ();
            var expected_state = Pomodoro.TimerState ();
            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    GLib.debug ("Event '%s'\n%s", event.spec.name, event.context.timer_state.to_representation ());

                    event_names += event.spec.name;

                    assert_cmpvariant (
                        event.context.timer_state.to_variant (),
                        expected_state.to_variant ()
                    );
                    assert_null (event.context.time_block);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("reset", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "stop",
                "change"
            });
        }

        public void test_timer_reset__paused ()
        {
            this.timer.start ();
            this.timer.pause ();

            var expected_timestamp = this.timer.state.paused_time + Pomodoro.Interval.MINUTE;
            var expected_state = Pomodoro.TimerState ();
            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    GLib.debug ("Event '%s'\n%s", event.spec.name, event.context.timer_state.to_representation ());

                    event_names += event.spec.name;

                    assert_cmpvariant (
                        event.context.timer_state.to_variant (),
                        expected_state.to_variant ()
                    );
                    assert_null (event.context.time_block);
                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("reset", null);

            // Expect "resume" event not to be triggered.
            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "stop",
                "change"
            });
        }

        public void test_timer_pause ()
        {
            this.timer.start ();

            var expected_timestamp = this.timer.state.started_time + Pomodoro.Interval.MINUTE;
            var expected_state = this.timer.state;
            expected_state.paused_time = expected_timestamp;

            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    assert_cmpvariant (
                        event.context.timer_state.to_variant (),
                        expected_state.to_variant ()
                    );
                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("pause", null);

            assert_cmpstrv (event_names, {
                "pause",
                "change"
            });
        }

        public void test_timer_resume ()
        {
            this.timer.start ();

            Pomodoro.Timestamp.advance (5 * Pomodoro.Interval.MINUTE);
            this.timer.pause ();

            var expected_timestamp = this.timer.state.paused_time + Pomodoro.Interval.MINUTE;
            var expected_state = this.timer.state;
            expected_state.offset = Pomodoro.Interval.MINUTE;
            expected_state.paused_time = Pomodoro.Timestamp.UNDEFINED;

            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    assert_cmpvariant (
                        event.context.timer_state.to_variant (),
                        expected_state.to_variant ()
                    );
                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("resume", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "resume",
                "change"
            });
        }

        public void test_timer_rewind ()
        {
            this.timer.start ();

            var expected_timestamp = this.timer.state.started_time + 5 * Pomodoro.Interval.MINUTE;
            var expected_state = this.timer.state;
            expected_state.offset = Pomodoro.Interval.MINUTE;

            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    assert_cmpvariant (
                        event.context.timer_state.to_variant (),
                        expected_state.to_variant ()
                    );
                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.timer_action_group.activate_action ("rewind", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "rewind",
                "change"
            });
        }

        public void test_timer_finished__continuous ()
        {
            this.timer.start ();

            var finished_time = this.session_manager.current_time_block.end_time;
            var expected_timestamp = finished_time;
            var event_names = new string[0];
            var finished = false;

            var expected_state_1 = this.timer.state;
            expected_state_1.finished_time = finished_time;

            var time_block_2 = this.session_manager.current_session.get_nth_time_block (1);
            var expected_state_2 = Pomodoro.TimerState () {
                duration = time_block_2.duration,
                started_time = finished_time,
                user_data = time_block_2
            };

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );

                    if (!finished) {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_1.to_variant ());
                    }
                    else {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_2.to_variant ());
                    }

                    if (event.spec.name == "finish") {
                        finished = true;
                    }
                });

            Pomodoro.Timestamp.freeze_to (finished_time);
            this.timer.finish ();

            assert_cmpstrv (event_names, {
                "finish",
                "state-change",
                "change",
                "advance"
            });
        }

        public void test_timer_finished__wait_for_activity ()
        {
            var idle_monitor = new Pomodoro.IdleMonitor.dummy ();
            assert_true (idle_monitor.provider is Pomodoro.DummyIdleMonitorProvider);

            this.session_manager.advance_to_state (Pomodoro.State.SHORT_BREAK);

            var finished_time = this.session_manager.current_time_block.end_time;
            var activity_time = finished_time + Pomodoro.Interval.MINUTE;
            var expected_timestamp = finished_time;
            var event_names = new string[0];
            var finished = false;
            var became_active = false;

            var time_block_1 = this.session_manager.current_time_block;
            var expected_state_1 = this.timer.state;
            expected_state_1.finished_time = finished_time;

            var time_block_2 = this.session_manager.current_session.get_next_time_block (time_block_1);
            var expected_state_2 = Pomodoro.TimerState () {
                duration = time_block_2.duration,
                started_time = Pomodoro.Timestamp.UNDEFINED,
                user_data = time_block_2
            };

            var expected_state_3 = expected_state_2;
            expected_state_3.started_time = activity_time;

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );

                    if (!finished) {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_1.to_variant ());
                    }
                    else if (!became_active) {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_2.to_variant ());
                    }
                    else {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_3.to_variant ());
                    }

                    if (event.spec.name == "finish") {
                        finished = true;
                    }
                });

            Pomodoro.Timestamp.freeze_to (finished_time);
            this.timer.finish ();

            assert_cmpstrv (event_names, {
                "finish",
                "state-change",
                "change",
                "advance"
            });

            // Simulate inactivity of 1 minute.
            became_active = true;
            expected_timestamp = activity_time;
            event_names = {};

            Pomodoro.Timestamp.freeze_to (activity_time);
            idle_monitor.provider.became_active ();

            assert_cmpstrv (event_names, {
                "reschedule",
                "change"
            });
        }

        public void test_timer_finished__manual ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-break", true);
            settings.set_boolean ("confirm-starting-pomodoro", true);

            this.timer.start ();

            var finished_time = this.session_manager.current_time_block.end_time;
            var confirmed_time = finished_time + Pomodoro.Interval.MINUTE;
            var expected_timestamp = finished_time;
            var event_names = new string[0];
            var confirmed = false;

            var time_block_1 = this.session_manager.current_time_block;
            var expected_state_1 = this.timer.state;
            expected_state_1.finished_time = finished_time;

            var time_block_2 = this.session_manager.current_session.get_next_time_block (time_block_1);
            var expected_state_2 = Pomodoro.TimerState () {
                duration = time_block_2.duration,
                started_time = confirmed_time,
                user_data = time_block_2
            };

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    assert_cmpvariant (
                        new GLib.Variant.int64 (event.context.timestamp),
                        new GLib.Variant.int64 (expected_timestamp)
                    );

                    if (!confirmed) {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_1.to_variant ());
                    }
                    else {
                        assert_cmpvariant (event.context.timer_state.to_variant (), expected_state_2.to_variant ());
                    }
                });

            Pomodoro.Timestamp.freeze_to (finished_time);
            this.timer.finish ();

            assert_cmpstrv (event_names, {
                "finish",
                "confirm-advancement"
            });

            // Confirm after 1 minute.
            confirmed = true;
            expected_timestamp = confirmed_time;
            event_names = {};

            Pomodoro.Timestamp.freeze_to (confirmed_time);
            this.session_manager_action_group.activate_action ("advance", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "change",
                "advance"
            });
        }

        /*
         * SessionManager
         */

        public void test_session_manager_advance__uncompleted ()
        {
            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    // TODO: check context
                });

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.session_manager_action_group.activate_action ("advance", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "change",
                "skip",
                "advance"
            });
        }

        public void test_session_manager_advance__completed ()
        {
            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var expected_timestamp = this.session_manager.current_time_block.end_time - Pomodoro.Interval.MINUTE;
            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    // TODO: check context
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.session_manager_action_group.activate_action ("advance", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "change",
                "advance"
            });
        }

        public void test_session_manager_advance__paused ()
        {
            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.timer.pause ();

            var expected_timestamp = Pomodoro.Timestamp.peek () + Pomodoro.Interval.MINUTE;
            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    // TODO: check context
                });

            Pomodoro.Timestamp.freeze_to (expected_timestamp);
            this.session_manager_action_group.activate_action ("advance", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "change",
                "skip",
                "advance"
            });
        }

        public void test_session_manager_confirm_advancement ()
        {
            var settings = Pomodoro.get_settings ();
            settings.set_boolean ("confirm-starting-break", true);
            settings.set_boolean ("confirm-starting-pomodoro", true);

            this.session_manager.advance_to_state (Pomodoro.State.POMODORO);

            var finished_time = this.session_manager.current_time_block.end_time;
            var confirmed_time = finished_time + Pomodoro.Interval.MINUTE;
            var expected_timestamp = finished_time;
            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    // TODO: check context
                });

            Pomodoro.Timestamp.freeze_to (finished_time);
            this.timer.finish ();

            assert_cmpstrv (event_names, {
                "finish",
                "confirm-advancement"
            });

            // Confirm after 1 minute.
            expected_timestamp = confirmed_time;
            event_names = {};

            Pomodoro.Timestamp.freeze_to (confirmed_time);
            this.session_manager_action_group.activate_action ("advance", null);

            assert_cmpstrv (event_names, {
                "reschedule",
                "state-change",
                "change",
                "advance"
            });
        }

        public void test_session_manager_session_expired ()
        {
            this.timer.start ();
            this.timer.pause ();

            var event_names = new string[0];
            var session_expired_emitted = 0;

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;

                    // TODO: check context
                });

            this.session_manager.session_expired.connect (() => {
                session_expired_emitted++;
            });

            Pomodoro.Timestamp.advance (Pomodoro.SessionManager.SESSION_EXPIRY_TIMEOUT + Pomodoro.Interval.MINUTE);
            this.session_manager.check_current_session_expired ();

            assert_cmpuint (session_expired_emitted, GLib.CompareOperator.EQ, 1);
            assert_cmpstrv (event_names, {
                "expire",
                "reschedule",
                "state-change",
                "change",
            });
        }

        public void test_session_manager_reset ()
        {
            this.timer.start ();

            Pomodoro.Timestamp.advance (Pomodoro.Interval.MINUTE);
            this.timer.reset ();

            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;
                });

            this.session_manager_action_group.activate_action ("reset", null);

            assert_cmpstrv (event_names, {
                "reset"
            });
        }

        public void test_session_manager_ensure_session ()
        {
            assert_null (this.session_manager.current_session);

            var event_names = new string[0];

            this.producer.event.connect (
                (event) => {
                    event_names += event.spec.name;
                });

            this.session_manager.ensure_session ();

            // Expect no events. "reschedule" will be emitted on timer start.
            assert_cmpstrv (event_names, {});
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.EventProducerTest ()
    );
}
