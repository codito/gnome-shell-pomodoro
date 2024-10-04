namespace Pomodoro
{
    [SingleInstance]
    public class SoundManager : GLib.Object
    {
        private const int64 SHORT_FADE_IN_DURATION  =  5 * Pomodoro.Interval.SECOND;
        private const int64 LONG_FADE_IN_DURATION   = 20 * Pomodoro.Interval.SECOND;
        private const int64 SHORT_FADE_OUT_DURATION =  2 * Pomodoro.Interval.SECOND;
        private const int64 LONG_FADE_OUT_DURATION  = 20 * Pomodoro.Interval.SECOND;
        private const int64 MIN_FADE_OUT_DURATION   =  1 * Pomodoro.Interval.SECOND;

        private Pomodoro.AlertSound?      pomodoro_finished_sound = null;
        private Pomodoro.AlertSound?      break_finished_sound = null;
        private Pomodoro.BackgroundSound? background_sound = null;
        private uint                      background_sound_inhibit_count = 0;
        private GLib.Settings?            settings = null;
        private Pomodoro.Timer?           timer = null;
        private ulong                     timer_state_changed_id = 0;
        private uint                      fade_out_timeout_id = 0;

        construct
        {
            this.timer = Pomodoro.Timer.get_default ();
            this.timer_state_changed_id = this.timer.state_changed.connect_after (this.on_timer_state_changed);

            this.pomodoro_finished_sound = new Pomodoro.AlertSound ("pomodoro-finished");
            this.break_finished_sound = new Pomodoro.AlertSound ("break-finished");
            this.background_sound = new Pomodoro.BackgroundSound ();
            this.background_sound.repeat = true;
            this.background_sound.fade_out (0);

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

            this.update_background_sound (true);
        }

        private void unschedule_fade_out ()
        {
            if (this.fade_out_timeout_id != 0) {
                GLib.Source.remove (this.fade_out_timeout_id);
                this.fade_out_timeout_id = 0;
            }
        }

        private void schedule_fade_out (int64 timeout)
                                        requires (this.fade_out_timeout_id == 0)
        {
            this.fade_out_timeout_id = GLib.Timeout.add (Pomodoro.Timestamp.to_milliseconds_uint (timeout),
                                                         this.on_fade_out_timeout);
            GLib.Source.set_name_by_id (this.fade_out_timeout_id, "Pomodoro.SoundManager.on_fade_out_timeout");
        }

        private void update_background_sound (bool shorter_fade_in = false)
        {
            this.unschedule_fade_out ();

            if (this.background_sound_inhibit_count != 0) {
                this.background_sound.fade_out (SHORT_FADE_OUT_DURATION, Pomodoro.Easing.OUT);
                return;
            }

            if (!this.background_sound.can_play ()) {
                this.background_sound.stop ();
                return;
            }

            var current_time_block = this.timer.user_data as Pomodoro.TimeBlock;
            var current_state = current_time_block != null
                    ? current_time_block.state
                    : Pomodoro.State.STOPPED;

            if (current_state == Pomodoro.State.POMODORO && this.timer.is_running ())
            {
                var remaining        = this.timer.calculate_remaining ();
                var fade_in_duration = shorter_fade_in ? SHORT_FADE_IN_DURATION : LONG_FADE_IN_DURATION;
                var fade_out_timeout = remaining - LONG_FADE_OUT_DURATION;

                if (fade_out_timeout > fade_in_duration) {
                    this.background_sound.fade_in (fade_in_duration);
                    this.schedule_fade_out (fade_out_timeout);
                }
                else if (remaining > MIN_FADE_OUT_DURATION) {
                    var volume = ((double) remaining / (double) LONG_FADE_OUT_DURATION).clamp (0.0, 1.0);

                    this.background_sound.fade_in_out (remaining, volume);
                }
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

            this.update_background_sound ();
        }

        private bool on_fade_out_timeout ()
                                          requires (this.timer.is_running ())
        {
            this.fade_out_timeout_id = 0;

            var current_time = this.timer.get_current_time (GLib.MainContext.current_source ().get_time ());
            var remaining = this.timer.calculate_remaining (current_time);

            this.background_sound.fade_out (remaining, Pomodoro.Easing.IN_OUT);

            return GLib.Source.REMOVE;
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

            if (this.background_sound != null) {
                this.background_sound.stop ();
                this.background_sound = null;
            }

            this.timer = null;
            this.settings = null;

            base.dispose ();
        }
    }
}
