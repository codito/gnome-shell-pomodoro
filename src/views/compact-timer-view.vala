namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/compact-timer-view.ui")]
    public class CompactTimerView : Gtk.Widget, Gtk.Buildable
    {
        [GtkChild]
        private unowned Gtk.MenuButton state_menubutton;
        [GtkChild]
        private unowned Pomodoro.TimerLabel timer_label;

        private Pomodoro.SessionManager session_manager;
        private Pomodoro.Timer          timer;
        private GLib.MenuModel?         state_menu;
        private GLib.MenuModel?         uniform_state_menu;
        private ulong                   timer_state_changed_id = 0;
        private ulong                   notify_current_time_block_id = 0;
        private ulong                   notify_has_uniform_breaks_id = 0;
        private ulong                   current_time_block_changed_id = 0;
        private Pomodoro.TimeBlock?     current_time_block;


        static construct
        {
            set_css_name ("compacttimerview");
        }

        construct
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = session_manager.timer;
            this.layout_manager  = new Gtk.BinLayout ();

            var builder = new Gtk.Builder.from_resource ("/org/gnomepomodoro/Pomodoro/ui/menus.ui");
            this.state_menu = (GLib.MenuModel) builder.get_object ("state_menu");
            this.uniform_state_menu = (GLib.MenuModel) builder.get_object ("uniform_state_menu");

            this.notify_current_time_block_id = this.session_manager.notify["current-time-block"].connect (
                this.on_session_manager_notify_current_time_block);
            this.notify_has_uniform_breaks_id = this.session_manager.notify["has-uniform-breaks"].connect (
                this.on_session_manager_notify_has_uniform_breaks);

            this.on_session_manager_notify_current_time_block ();
            this.on_session_manager_notify_has_uniform_breaks ();
        }

        private string get_state_label ()
        {
            var current_time_block = this.session_manager.current_time_block;
            var current_state = current_time_block != null
                    ? current_time_block.state : Pomodoro.State.STOPPED;

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
            this.state_menubutton.label = !this.timer.is_finished ()
                ? this.get_state_label ()
                : _("Finished!");
        }

        private void update_timer_label_placeholder ()
        {
            var session_template = this.session_manager.scheduler.session_template;

            this.timer_label.placeholder_has_hours = session_template.pomodoro_duration >= Pomodoro.Interval.HOUR;
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.update_css_classes ();
            this.update_buttons ();
            this.update_timer_label_placeholder ();
        }

        private void on_current_time_block_changed ()
        {
            this.update_buttons ();
        }

        private void on_session_manager_notify_current_time_block ()
        {
            var current_time_block = this.session_manager.current_time_block;

            if (this.current_time_block_changed_id != 0) {
                this.current_time_block.disconnect (this.current_time_block_changed_id);
                this.current_time_block_changed_id = 0;
            }

            if (current_time_block != null) {
                this.current_time_block_changed_id = current_time_block.changed.connect (this.on_current_time_block_changed);
            }

            this.current_time_block = current_time_block;

            this.on_current_time_block_changed ();
        }

        private void on_session_manager_notify_has_uniform_breaks ()
        {
            this.state_menubutton.menu_model = this.session_manager.has_uniform_breaks
                ? this.uniform_state_menu
                : this.state_menu;
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
            this.session_manager.ensure_session ();

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

            if (this.current_time_block_changed_id != 0) {
                this.current_time_block.disconnect (this.current_time_block_changed_id);
                this.current_time_block_changed_id = 0;
            }

            if (this.notify_current_time_block_id != 0) {
                this.session_manager.disconnect (this.notify_current_time_block_id);
                this.notify_current_time_block_id = 0;
            }

            if (this.notify_has_uniform_breaks_id != 0) {
                this.session_manager.disconnect (this.notify_has_uniform_breaks_id);
                this.notify_has_uniform_breaks_id = 0;
            }

            this.state_menu = null;
            this.uniform_state_menu = null;
            this.current_time_block = null;
            this.session_manager = null;
            this.timer = null;

            base.dispose ();
        }
    }
}
