namespace Pomodoro
{
    /**
     * `NotificationManager` manages notification popups and the screen overlay.
     */
    public class NotificationManager : GLib.Object
    {
        private static Pomodoro.NotificationManager? instance = null;

        public Pomodoro.Timer timer {
            get {
                return this._timer;
            }
            construct {
                this._timer = value;

                this.timer_finished_id = this._timer.finished.connect (this.on_timer_finished);
                this.timer_state_changed_id = this._timer.state_changed.connect (this.on_timer_state_changed);
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

        private Pomodoro.Timer?          _timer = null;
        private Pomodoro.SessionManager? _session_manager = null;
        private GLib.Settings?           settings = null;
        private ulong                    timer_finished_id = 0;
        private ulong                    timer_state_changed_id = 0;
        private ulong                    session_manager_confirm_advancement_id = 0;
        private GLib.Notification?       notification;


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

            this.settings.changed.connect (this.on_settings_changed);
        }

        public static void set_default (Pomodoro.NotificationManager? notification_manager)
        {
            Pomodoro.NotificationManager.instance = notification_manager;
        }

        public static unowned Pomodoro.NotificationManager get_default ()
        {
            if (Pomodoro.NotificationManager.instance == null) {
                Pomodoro.NotificationManager.set_default (new Pomodoro.NotificationManager ());
            }

            return Pomodoro.NotificationManager.instance;
        }

        private void withdraw_notifications ()
        {
            // if (this.overlay_notification != null) {
            //     this.overlay_notification.close ();
            // }

            GLib.Application.get_default ()
                            .withdraw_notification ("timer");
        }

        private void on_timer_finished (Pomodoro.TimerState state)
        {
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.withdraw_notifications ();
        }

        private void on_session_manager_confirm_advancement (Pomodoro.TimeBlock current_time_block,
                                                             Pomodoro.TimeBlock next_time_block)
        {
            var have_actions = true;  // TODO: should be a manager property
            var title = "";
            var body = "";
            var action_label = "";

            switch (current_time_block.state)
            {
                case Pomodoro.State.POMODORO:
                    title = _("Pomodoro is over!");
                    break;

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

            var notification = new GLib.Notification (title);
            notification.set_priority (GLib.NotificationPriority.URGENT);
            notification.set_body (body);
            notification.set_default_action_and_target_value ("app.timer", new GLib.Variant.int64 (Pomodoro.Timestamp.UNDEFINED));

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            } catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            if (next_time_block.state.is_break ()) {
                notification.add_button_with_target_value (_("Skip Break"),
                                                           "app.advance-to-state",
                                                           new GLib.Variant.string ("pomodoro"));
            }

            notification.add_button (action_label, "app.advance");

            this.notification = notification;

            GLib.Application.get_default ()
                            .send_notification ("timer", notification);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
        }

        public override void dispose ()
        {
            // this.withdraw_notifications ();  // FIXME: causes infinite loop when closing the app

            if (this.timer_finished_id != 0) {
                this._timer.disconnect (this.timer_finished_id);
                this.timer_finished_id = 0;
            }

            if (this.timer_state_changed_id != 0) {
                this._timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            if (this.session_manager_confirm_advancement_id != 0) {
                this._session_manager.disconnect (this.session_manager_confirm_advancement_id);
                this.session_manager_confirm_advancement_id = 0;
            }

            // FIXME
            // this.settings.changed.disconnect (this.on_settings_changed);

            this._timer = null;
            this._session_manager = null;
            this.settings = null;
            this.notification = null;

            base.dispose ();

            // FIXME
            // if (Pomodoro.NotificationManager.instance == this) {
            //     Pomodoro.NotificationManager.instance = null;
            // }
        }
    }
}
