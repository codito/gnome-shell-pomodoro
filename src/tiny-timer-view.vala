
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/tiny-timer-view.ui")]
    public class TinyTimerView : Gtk.Widget, Gtk.Buildable
    {
        // [GtkChild]
        // private unowned Gtk.MenuButton timer_state_menubutton;
        // [GtkChild]
        // private unowned Pomodoro.TimerProgressBar timer_progressbar;
        // [GtkChild]
        // private unowned Pomodoro.SessionProgressBar session_progressbar;
        // [GtkChild]
        // private unowned Gtk.GestureClick click_gesture;
        // [GtkChild]
        // private unowned Gtk.GestureDrag drag_gesture;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private ulong                   timer_state_changed_id = 0;


        static construct
        {
            set_css_name ("tinytimerview");
        }

        construct
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.layout_manager  = new Gtk.BinLayout ();
        }

        private void update_css_classes ()
        {
            // if (this.timer.is_running ()) {
            //     this.timer_state_menubutton.add_css_class ("timer-running");
            //     this.session_progressbar.add_css_class ("timer-running");
            // }
            // else {
            //     this.timer_state_menubutton.remove_css_class ("timer-running");
            //     this.session_progressbar.add_css_class ("timer-running");
            // }
        }

        private void update_buttons ()
        {
            var current_time_block = this.session_manager.current_time_block;

            // this.timer_state_menubutton.label = current_time_block != null
            //     ? current_time_block.state.get_label ()
            //     : _("Stopped");
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.update_css_classes ();
            this.update_buttons ();
        }

        private void connect_signals ()
        {
            if (this.timer_state_changed_id == 0) {
                this.timer_state_changed_id = timer.state_changed.connect (this.on_timer_state_changed);
            }
        }

        private void disconnect_signals ()
        {
            if (this.timer_state_changed_id != 0) {
                this.timer.disconnect (this.timer_state_changed_id);
                this.timer_state_changed_id = 0;
            }
        }

        public override void map ()
        {
            this.on_timer_state_changed (this.timer.state, this.timer.state);

            base.map ();

            this.connect_signals ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.disconnect_signals ();
       }

        public override void dispose ()
        {
            this.disconnect_signals ();

            base.dispose ();
        }
    }
}
