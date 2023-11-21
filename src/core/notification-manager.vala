namespace Pomodoro
{
    private enum NotificationType
    {
        NULL,
        TIME_BLOCK_ABOUT_TO_END,
        TIME_BLOCK_ENDED,
        TIME_BLOCK_STARTED,
        TIME_BLOCK_RUNNING,
        CONFIRM_ADVANCEMENT
    }


    /**
     * `NotificationManager` manages notification popups and the screen overlay.
     */
    [SingleInstance]
    public class NotificationManager : GLib.Object
    {
        /**
         * Notifications may contain remaining time. As we can't update it gracefully the most sensible way is to
         * dismiss the notification when it's getting stale. The timeout is higher to allow urgent notifications be
         * shown. Unfortunately, we may dismiss the notification before it gets acknowledged.
         */
        private const uint WITHDRAW_TIMEOUT_SECONDS = 30;

        /**
         * User may pause the timer right after the time-block started via custom actions. This const is the tolerance
         * for displaying the time-block-started notification.
         */
        private const int64 TIME_BLOCK_STARTED_TOLERANCE = Pomodoro.Interval.SECOND;

        private const int64 TIME_BLOCK_ABOUT_TO_END_TIMEOUT = 10 * Pomodoro.Interval.SECOND;
        private const int64 TIME_BLOCK_ABOUT_TO_END_TOLERANCE = 5 * Pomodoro.Interval.SECOND;


        // private static Pomodoro.NotificationManager? instance = null;

        public Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            construct {
                this._timer = value;

                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
                this.timer_tick_id = this._timer.tick.connect (this.on_timer_tick);

                this.on_timer_state_changed (this._timer.state, this._timer.state);
            }
        }

        public Pomodoro.SessionManager session_manager {
            get {
                return this._session_manager;
            }
            construct {
                this._session_manager = value;

                this.session_manager_confirm_advancement_id = this._session_manager.confirm_advancement.connect (
                        this.on_session_manager_confirm_advancement);
            }
        }

        private Pomodoro.Timer?           _timer = null;
        private Pomodoro.SessionManager?  _session_manager = null;
        private GLib.Settings?            settings = null;
        private ulong                     timer_state_changed_id = 0;
        private ulong                     timer_tick_id = 0;
        private ulong                     settings_changed_id = 0;
        private ulong                     session_manager_confirm_advancement_id = 0;
        private uint                      notify_time_block_ended_idle_id = 0;
        private uint                      withdraw_timeout_id = 0;
        private bool                      screen_overlay_active = false;
        private int                       screen_overlay_inhibit_count = 0;
        private GLib.Notification?        notification = null;
        private Pomodoro.NotificationType notification_type = NotificationType.NULL;
        private weak Pomodoro.TimeBlock?  notification_time_block = null;

        public NotificationManager ()
        {
            GLib.Object (
                timer: Pomodoro.Timer.get_default (),
                session_manager: Pomodoro.SessionManager.get_default ()
            );
        }

        construct
        {
            this.settings = Pomodoro.get_settings ();

            this.settings_changed_id = this.settings.changed.connect (this.on_settings_changed);
        }

        // public static void set_default (Pomodoro.NotificationManager? notification_manager)
        // {
        //     Pomodoro.NotificationManager.instance = notification_manager;
        // }

        // public static unowned Pomodoro.NotificationManager get_default ()
        // {
        //     if (Pomodoro.NotificationManager.instance == null) {
        //         Pomodoro.NotificationManager.set_default (new Pomodoro.NotificationManager ());
        //     }
        //
        //     return Pomodoro.NotificationManager.instance;
        // }

        private string format_remaining_time (Pomodoro.TimeBlock time_block)
        {
            var timestamp = this._timer.get_last_tick_time ();
            var seconds = Pomodoro.Timestamp.to_seconds (time_block.calculate_remaining (timestamp));
            var seconds_uint = (uint) Pomodoro.round_seconds (seconds);

            // translators: time remaining eg. "3 minutes 50 seconds remaining"
            return _("%s remaining").printf (Pomodoro.format_time (seconds_uint));
        }

        private void remove_withdraw_timeout ()
        {
            if (this.withdraw_timeout_id != 0) {
                GLib.Source.remove (this.withdraw_timeout_id);
                this.withdraw_timeout_id = 0;
            }
        }

        private void withdraw_notifications ()
        {
            this.remove_withdraw_timeout ();

            GLib.Application.get_default ()
                            .withdraw_notification ("timer");

            this.notification = null;
            this.notification_type = Pomodoro.NotificationType.NULL;
            this.notification_time_block = null;
        }

        private void schedule_withdraw_notifications ()
        {
            this.remove_withdraw_timeout ();

            // TODO: ensure user is active / acknowledged notification

            this.withdraw_timeout_id = GLib.Timeout.add_seconds (
                WITHDRAW_TIMEOUT_SECONDS,
                () => {
                    this.withdraw_timeout_id = 0;
                    this.withdraw_notifications ();

                    return GLib.Source.REMOVE;
                }
            );
            GLib.Source.set_name_by_id (this.withdraw_timeout_id,
                                        "Pomodoro.NotificationManager.schedule_withdraw_notifications");
        }

        private GLib.Notification create_notification (string title,
                                                       string body)
        {
            var notification = new GLib.Notification (title);
            notification.set_priority (GLib.NotificationPriority.HIGH);
            notification.set_default_action_and_target_value ("app.timer", new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED));

            if (body != "") {
                notification.set_body (body);
            }

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            return notification;
        }

        /**
         * Show notification informing that the time-block has started.
         */
        private void notify_time_block_started (Pomodoro.TimeBlock time_block)
        {
            var title = "";
            var body = this.format_remaining_time (time_block);

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    title = _("Pomodoro");
                    break;

                case Pomodoro.State.BREAK:
                    title = _("Take a break");
                    break;

                case Pomodoro.State.SHORT_BREAK:
                    title = _("Take a short break");
                    break;

                case Pomodoro.State.LONG_BREAK:
                    title = _("Take a long break");
                    break;

                default:
                    assert_not_reached ();
            }

            this.notification = this.create_notification (title, body);
            this.notification_type = Pomodoro.NotificationType.TIME_BLOCK_STARTED;
            this.notification_time_block = time_block;

            GLib.Application.get_default ()
                            .send_notification ("timer", this.notification);

            this.schedule_withdraw_notifications ();
        }

        /**
         * Show notification with current state and remaining time.
         */
        private void notify_time_block_running (Pomodoro.TimeBlock time_block)
        {
            var title = time_block.state.get_label ();
            var body = this.format_remaining_time (time_block);

            this.notification = this.create_notification (title, body);
            this.notification_type = Pomodoro.NotificationType.TIME_BLOCK_RUNNING;
            this.notification_time_block = time_block;

            GLib.Application.get_default ()
                            .send_notification ("timer", this.notification);

            this.schedule_withdraw_notifications ();
        }

        /**
         * Show notification informing that the time-block has ended.
         */
        private void notify_time_block_about_to_end (Pomodoro.TimeBlock time_block)
        {
            var title = "";
            var body = "";
            var action_label = "";

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    title = _("Pomodoro is about to end");
                    action_label = _("Take a Break");
                    break;

                case Pomodoro.State.BREAK:
                case Pomodoro.State.SHORT_BREAK:
                case Pomodoro.State.LONG_BREAK:
                    title = _("Break is about to end");
                    action_label = _("Start Pomodoro");
                    break;

                default:
                    assert_not_reached ();
            }

            var notification = this.create_notification (title, body);
            notification.set_priority (GLib.NotificationPriority.URGENT);
            notification.add_button_with_target_value (_("+1 minute"), "app.extend", 60U);
            notification.add_button (action_label, "app.advance");

            this.notification = notification;
            this.notification_type = Pomodoro.NotificationType.TIME_BLOCK_ABOUT_TO_END;
            this.notification_time_block = time_block;

            GLib.Application.get_default ()
                            .send_notification ("timer", this.notification);

            this.remove_withdraw_timeout ();
        }

        /**
         * Show notification informing that the time-block has ended.
         *
         * It's only shown when waiting for activity.
         */
        private void notify_time_block_ended (Pomodoro.TimeBlock time_block)
        {
            var title = "";
            var body = _("Get ready…");

            switch (time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    title = _("Pomodoro is over!");
                    break;

                case Pomodoro.State.BREAK:
                case Pomodoro.State.SHORT_BREAK:
                case Pomodoro.State.LONG_BREAK:
                    title = _("Break is over!");
                    break;

                default:
                    assert_not_reached ();
            }

            this.notification = this.create_notification (title, body);
            this.notification_type = Pomodoro.NotificationType.TIME_BLOCK_ENDED;
            this.notification_time_block = time_block;

            GLib.Application.get_default ()
                            .send_notification ("timer", this.notification);

            this.remove_withdraw_timeout ();
        }

        /**
         * Show notification with emphasis on confirming advancement to the next time-block.
         */
        private void notify_confirm_advancement (Pomodoro.TimeBlock current_time_block,
                                                 Pomodoro.TimeBlock next_time_block)
        {
            var title = "";
            var body = "";
            var action_label = "";

            switch (current_time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    title = _("Pomodoro is over!");
                    break;

                case Pomodoro.State.BREAK:
                case Pomodoro.State.SHORT_BREAK:
                case Pomodoro.State.LONG_BREAK:
                    title = _("Break is over!");
                    break;

                default:
                    assert_not_reached ();
            }

            switch (next_time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    body = _("Confirm the start of a Pomodoro…");
                    action_label = _("Start Pomodoro");
                    break;

                case Pomodoro.State.BREAK:
                    body = _("Confirm the start of a break…");
                    action_label = _("Take a Break");
                    break;

                case Pomodoro.State.SHORT_BREAK:
                    body = _("Confirm the start of a short break…");
                    action_label = _("Take a Break");
                    break;

                case Pomodoro.State.LONG_BREAK:
                    body = _("Confirm the start of a long break…");
                    action_label = _("Take a Break");
                    break;

                default:
                    assert_not_reached ();
            }

            var notification = this.create_notification (title, body);
            notification.set_priority (GLib.NotificationPriority.URGENT);

            if (next_time_block.state.is_break ()) {
                notification.add_button_with_target_value (_("Skip Break"),
                                                           "app.advance-to-state",
                                                           new GLib.Variant.string ("pomodoro"));
            }

            notification.add_button (action_label, "app.advance");

            this.notification = notification;
            this.notification_type = Pomodoro.NotificationType.CONFIRM_ADVANCEMENT;
            this.notification_time_block = current_time_block;

            GLib.Application.get_default ()
                            .send_notification ("timer", this.notification);

            this.remove_withdraw_timeout ();
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            var current_time_block = current_state.user_data as Pomodoro.TimeBlock;
            var timestamp = this._timer.get_last_state_changed_time ();

            if (this.notify_time_block_ended_idle_id != 0) {
                GLib.Source.remove (this.notify_time_block_ended_idle_id);
                this.notify_time_block_ended_idle_id = 0;
            }

            if (current_state.is_paused ())
            {
                var elapsed = Pomodoro.Timestamp.subtract (timestamp, current_state.started_time);

                // The timer may be paused externally after start. This should not happen in normal operation.
                if (elapsed <= TIME_BLOCK_STARTED_TOLERANCE) {
                    this.notify_time_block_started (current_time_block);
                }
                else {
                    this.withdraw_notifications ();
                }

                if (this.screen_overlay_active) {
                    this.close_screen_overlay ();
                }
            }
            else if (current_state.is_finished () && !previous_state.is_finished ())
            {
                this.notify_time_block_ended_idle_id = GLib.Idle.add (
                    () => {
                        this.notify_time_block_ended_idle_id = 0;

                        if (this.notification_type == Pomodoro.NotificationType.CONFIRM_ADVANCEMENT) {
                            return GLib.Source.REMOVE;
                        }

                        this.notify_time_block_ended (current_time_block);

                        return GLib.Source.REMOVE;
                    },
                    GLib.Priority.HIGH_IDLE
                );
                GLib.Source.set_name_by_id (this.notify_time_block_ended_idle_id,
                                            "Pomodoro.NotificationManager.notify_time_block_ended");

                if (this.screen_overlay_active) {
                    this.close_screen_overlay ();
                }
            }
            else if (current_state.is_started ())
            {
                var remaining = this._timer.calculate_remaining (timestamp);
                var about_to_end_threshold = TIME_BLOCK_ABOUT_TO_END_TIMEOUT +
                                             TIME_BLOCK_ABOUT_TO_END_TOLERANCE;

                if (current_time_block.state.is_break () &&
                    screen_overlay_inhibit_count == 0 &&
                    remaining >= about_to_end_threshold &&
                    this.settings.get_boolean ("show-screen-overlay"))
                {
                    if (!this.screen_overlay_active) {
                        this.open_screen_overlay ();
                    }

                    return;
                }

                if (current_state.started_time == timestamp) {
                    this.notify_time_block_started (current_time_block);
                }
                else if (remaining < about_to_end_threshold) {
                    this.notify_time_block_about_to_end (current_time_block);
                }
                else {
                    this.notify_time_block_running (current_time_block);
                }
            }
            else {
                this.withdraw_notifications ();

                if (this.screen_overlay_active) {
                    this.close_screen_overlay ();
                }
            }
        }

        private void on_timer_tick (int64 timestamp)
        {
            var remaining = this._timer.calculate_remaining (timestamp);

            if (remaining <= TIME_BLOCK_ABOUT_TO_END_TIMEOUT && !(
                this.notification_type == Pomodoro.NotificationType.TIME_BLOCK_ABOUT_TO_END ||
                this.notification_type == Pomodoro.NotificationType.TIME_BLOCK_ENDED ||
                this.notification_type == Pomodoro.NotificationType.CONFIRM_ADVANCEMENT))
            {
                this.notify_time_block_about_to_end (this.session_manager.current_time_block);
            }
        }

        private void on_session_manager_confirm_advancement (Pomodoro.TimeBlock current_time_block,
                                                             Pomodoro.TimeBlock next_time_block)
        {
            this.notify_confirm_advancement (current_time_block, next_time_block);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            var current_time_block = this._session_manager.current_time_block;

            switch (key)
            {
                case "show-screen-overlay":
                    if (this.screen_overlay_inhibit_count == 0) {
                        this.on_timer_state_changed (this._timer.state, this._timer.state);
                    }

                    break;
            }
        }

        public signal void open_screen_overlay ()
        {
            debug ("open_screen_overlay");

            this.screen_overlay_active = true;

            this.withdraw_notifications ();
        }

        public signal void close_screen_overlay ()
        {
            debug ("close_screen_overlay");

            this.screen_overlay_active = false;

            this.screen_overlay_inhibit_count++;
            this.on_timer_state_changed (this._timer.state, this._timer.state);
            this.screen_overlay_inhibit_count--;
        }

        public override void dispose ()
        {
            this.withdraw_notifications ();

            if (this.screen_overlay_active) {
                this.close_screen_overlay ();
            }

            if (this.notify_time_block_ended_idle_id != 0) {
                GLib.Source.remove (this.notify_time_block_ended_idle_id);
                this.notify_time_block_ended_idle_id = 0;
            }

            if (this.timer_tick_id != 0) {
                this._timer.disconnect (this.timer_tick_id);
                this.timer_tick_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            if (this.session_manager_confirm_advancement_id != 0) {
                this._session_manager.disconnect (this.session_manager_confirm_advancement_id);
                this.session_manager_confirm_advancement_id = 0;
            }

            if (this.settings_changed_id != 0) {
                this.settings.disconnect (this.settings_changed_id);
                this.settings_changed_id = 0;
            }

            this._timer = null;
            this._session_manager = null;
            this.settings = null;
            this.notification = null;
            this.notification_time_block = null;

            base.dispose ();

            debug ("### disposed");

            // FIXME
            // if (Pomodoro.NotificationManager.instance == this) {
            //     Pomodoro.NotificationManager.instance = null;
            // }
        }
    }
}
