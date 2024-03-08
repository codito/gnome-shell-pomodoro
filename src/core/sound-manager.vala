namespace Pomodoro
{
    [SingleInstance]
    public class SoundManager : GLib.Object
    {
        private const Pomodoro.StateFlags BACKGROUND_SOUND_CONDITION = Pomodoro.StateFlags.POMODORO |
                                                                       Pomodoro.StateFlags.RUNNING;

        private const int64 FADE_IN_SHORT_DURATION = 5 * Pomodoro.Interval.SECOND;
        private const int64 FADE_IN_LONG_DURATION = 20 * Pomodoro.Interval.SECOND;
        private const int64 FADE_OUT_SHORT_DURATION = 2 * Pomodoro.Interval.SECOND;
        private const int64 FADE_OUT_LONG_DURATION = 20 * Pomodoro.Interval.SECOND;

        private Pomodoro.AlertSound?      pomodoro_finished_sound = null;
        private Pomodoro.AlertSound?      break_finished_sound = null;
        private Pomodoro.BackgroundSound? background_sound = null;
        private uint                      background_sound_inhibit_count = 0;
        private uint                      background_sound_condition_watch_id = 0;
        private GLib.Settings?            settings = null;
        private Pomodoro.Timer?           timer = null;
        private ulong                     timer_state_changed_id = 0;
        private Pomodoro.StateMonitor?    state_monitor = null;
        private uint                      fade_out_timeout_id = 0;

        construct
        {
            this.timer = Pomodoro.Timer.get_default ();
            this.timer_state_changed_id = this.timer.state_changed.connect_after (this.on_timer_state_changed);

            this.state_monitor = new Pomodoro.StateMonitor ();

            this.pomodoro_finished_sound = new Pomodoro.AlertSound ("pomodoro-finished");
            this.break_finished_sound = new Pomodoro.AlertSound ("break-finished");
            this.background_sound = new Pomodoro.BackgroundSound ();
            this.background_sound.repeat = true;

            this.settings = Pomodoro.get_settings ();
            this.settings.bind ("pomodoro-finished-sound",
                                this.pomodoro_finished_sound,
                                "uri",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("pomodoro-finished-sound-volume",
                                this.pomodoro_finished_sound,
                                "volume",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("break-finished-sound",
                                this.break_finished_sound,
                                "uri",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("break-finished-sound-volume",
                                this.break_finished_sound,
                                "volume",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("background-sound",
                                this.background_sound,
                                "uri",
                                GLib.SettingsBindFlags.DEFAULT);
            this.settings.bind ("background-sound-volume",
                                this.background_sound,
                                "volume",
                                GLib.SettingsBindFlags.DEFAULT);

            this.background_sound_condition_watch_id = this.state_monitor.add_watch (
                                BACKGROUND_SOUND_CONDITION,
                                Pomodoro.StateFlags.NONE,
                                this.on_background_sound_condition_enter,
                                this.on_background_sound_condition_leave);

            this.update_background_sound ();
        }

        private void unschedule_fade_out ()
        {
            if (this.fade_out_timeout_id != 0) {
                GLib.Source.remove (this.fade_out_timeout_id);
                this.fade_out_timeout_id = 0;
            }
        }

        private void schedule_fade_out ()
        {
            unschedule_fade_out ();

            // TODO: StateMonitor should estimate end tome of the condition
            if (!this.timer.is_running ()) {
                return;
            }

            var remaining = this.timer.calculate_remaining ();
            var fade_out_timeout = remaining - FADE_OUT_LONG_DURATION;

            if (fade_out_timeout > 0)
            {
                this.fade_out_timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (fade_out_timeout),
                                                             this.on_fade_out_timeout);
                GLib.Source.set_name_by_id (this.fade_out_timeout_id, "Pomodoro.SoundManager.on_fade_out_timeout");
            }
            else {
                // No timeout can be determined.
            }
        }

        private bool check_background_sound_condition ()
        {
            return BACKGROUND_SOUND_CONDITION in this.state_monitor.current_state_flags;
        }

        private void update_background_sound (bool was_inhibited = false)
        {
            this.unschedule_fade_out ();

            if (this.background_sound_inhibit_count != 0) {
                this.background_sound.fade_out (FADE_OUT_SHORT_DURATION, Pomodoro.Easing.OUT);
                return;
            }

            if (!this.background_sound.can_play ()) {
                this.background_sound.stop ();
                return;
            }

            if (this.check_background_sound_condition ())
            {
                this.background_sound.fade_in (this.timer.state.offset == 0 && !was_inhibited
                                               ? FADE_IN_LONG_DURATION : FADE_IN_SHORT_DURATION);
                this.schedule_fade_out ();
            }
            else {
                this.background_sound.stop ();
            }
        }

        public void inhibit_background_sound ()
        {
            this.background_sound_inhibit_count++;

            if (this.background_sound_inhibit_count == 1)
            {
                this.update_background_sound ();
            }
        }

        public void uninhibit_background_sound ()
        {
            this.background_sound_inhibit_count--;

            if (this.background_sound_inhibit_count == 0)
            {
                this.update_background_sound (true);
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            if (current_state.is_finished () && !previous_state.is_finished ())
            {
                var current_time_block = current_state.user_data as Pomodoro.TimeBlock;

                if (current_time_block.state == Pomodoro.State.POMODORO) {
                    this.pomodoro_finished_sound.play ();
                }
                else if (current_time_block.state.is_break ()) {
                    this.break_finished_sound.play ();
                }
            }
        }

        private bool on_fade_out_timeout ()
                                          requires (this.timer.is_running ())
        {
            var current_time = this.timer.get_current_time (GLib.MainContext.current_source ().get_time ());
            var remaining = this.timer.calculate_remaining (current_time);

            this.background_sound.fade_out (remaining, Pomodoro.Easing.IN_OUT);
            this.fade_out_timeout_id = 0;

            return GLib.Source.REMOVE;
        }

        private void on_background_sound_condition_enter ()
        {
            this.update_background_sound ();
        }

        private void on_background_sound_condition_leave ()
        {
            this.update_background_sound ();
        }

        public override void dispose ()
        {
            this.unschedule_fade_out ();

            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }

            if (this.pomodoro_finished_sound != null) {
                this.pomodoro_finished_sound.stop ();
                this.pomodoro_finished_sound = null;
            }

            if (this.break_finished_sound != null) {
                this.break_finished_sound.stop ();
                this.break_finished_sound = null;
            }

            if (this.background_sound_condition_watch_id != 0) {
                this.state_monitor.remove_watch (this.background_sound_condition_watch_id);
                this.background_sound_condition_watch_id = 0;
            }

            if (this.background_sound != null) {
                this.background_sound.stop ();
                this.background_sound = null;
            }

            this.timer = null;
            this.settings = null;
            this.state_monitor = null;

            base.dispose ();
        }
    }
}
