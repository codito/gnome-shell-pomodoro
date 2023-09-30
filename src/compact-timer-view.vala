
namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/compact-timer-view.ui")]
    public class CompactTimerView : Gtk.Widget, Gtk.Buildable
    {
        [GtkChild]
        private unowned Gtk.MenuButton state_menubutton;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private ulong                   timer_state_changed_id = 0;


        static construct
        {
            set_css_name ("compacttimerview");
        }

        construct
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.layout_manager  = new Gtk.BinLayout ();
        }

        private string get_state_label ()
        {
            var current_time_block = this.session_manager.current_time_block;
            var current_state = current_time_block != null ? current_time_block.state : Pomodoro.State.UNDEFINED;

            return current_state.get_label ();
        }

        private void update_css_classes ()
        {
            if (this.timer.is_running ()) {
                this.state_menubutton.add_css_class ("timer-running");
            }
            else {
                this.state_menubutton.remove_css_class ("timer-running");
            }
        }

        private void update_buttons ()
        {
            this.state_menubutton.label = this.get_state_label ();
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
