using GLib;


namespace Pomodoro
{
    public delegate void EnterStateCallback ();

    public delegate void LeaveStateCallback ();


    [SingleInstance]
    public sealed class StateMonitor : GLib.Object
    {
        private static uint next_watch_id = 1;

        // [Compact]
        private class Watch
        {
            public Pomodoro.StateFlags                  condition = Pomodoro.StateFlags.NONE;
            public Pomodoro.StateFlags                  precondition = Pomodoro.StateFlags.NONE;
            public unowned Pomodoro.EnterStateCallback? enter_state_callback = null;
            public unowned Pomodoro.LeaveStateCallback? leave_state_callback = null;
            public bool                                 active = false;

            public inline bool is_stateful ()
            {
                return this.leave_state_callback != null;
            }

            public bool check (Pomodoro.StateFlags current_state_flags,
                               Pomodoro.StateFlags previous_state_flags)
            {
                if (this.condition != Pomodoro.StateFlags.NONE && this.condition in current_state_flags)
                {
                    return this.precondition == Pomodoro.StateFlags.NONE ||
                           this.precondition in previous_state_flags;
                }

                return false;
            }

            public void set_active (bool active)
            {
                if (active == this.active) {
                    return;
                }

                this.active = active;

                if (active)
                {
                    if (this.enter_state_callback != null) {
                        this.enter_state_callback ();
                    }
                }
                else {
                    if (this.leave_state_callback != null) {
                        this.leave_state_callback ();
                    }
                }
            }

            public void trigger ()
            {
                if (this.enter_state_callback != null) {
                    this.enter_state_callback ();
                }
            }
        }

        struct Snapshot
        {
            public unowned Watch watch;
            public bool          active;
        }

        public Pomodoro.Timer timer { get; construct; }

        public Pomodoro.StateFlags current_state_flags {
            get {
                return this._current_state_flags;
            }
        }

        private Pomodoro.StateFlags           _current_state_flags = Pomodoro.StateFlags.NONE;
        private GLib.HashTable<int64?, Watch> watches;

        construct
        {
            this.watches = new GLib.HashTable<int64?, Watch> (int64_hash, int64_equal);

            this.timer.state_changed.connect_after (this.on_timer_state_changed);

            this.update_current_state_flags ();
        }

        public StateMonitor ()
        {
            GLib.Object (
                timer: Pomodoro.Timer.get_default ()
            );
        }

        private void update_current_state_flags ()
        {
            var timer_state = this.timer.state;
            var current_time_block = this.timer.user_data as Pomodoro.TimeBlock;
            var current_state_flags = Pomodoro.StateFlags.NONE;
            var previous_state_flags = this._current_state_flags;

            current_state_flags |= timer_state.user_data != null
                ? Pomodoro.StateFlags.ENABLED
                : Pomodoro.StateFlags.DISABLED;

            if (timer_state.is_started ())
            {
                current_state_flags |= Pomodoro.StateFlags.STARTED;

                if (timer_state.is_running ()) {
                    current_state_flags |= Pomodoro.StateFlags.RUNNING;
                }

                if (timer_state.is_paused ()) {
                    current_state_flags |= Pomodoro.StateFlags.PAUSED;
                }

                if (timer_state.is_finished ()) {
                    current_state_flags |= Pomodoro.StateFlags.FINISHED;
                }
                else {
                    current_state_flags |= Pomodoro.StateFlags.UNFINISHED;
                }
            }

            if (current_time_block != null)
            {
                if (current_time_block.state == Pomodoro.State.POMODORO) {
                    current_state_flags |= Pomodoro.StateFlags.POMODORO;
                }
                else if (current_time_block.state.is_break ()) {
                    current_state_flags |= Pomodoro.StateFlags.BREAK;
                }
            }

            if (current_state_flags != previous_state_flags)
            {
                Snapshot[] snapshots = {};

                this.watches.@foreach (
                    (id, watch) => {
                        var should_be_active = watch.check (current_state_flags, previous_state_flags);

                        if (watch.active != should_be_active)
                        {
                            snapshots += Snapshot () {
                                watch = watch,
                                active = should_be_active
                            };
                        }
                    });

                this._current_state_flags = current_state_flags;

                foreach (var snapshot in snapshots)
                {
                    if (snapshot.watch.is_stateful ()) {
                        snapshot.watch.set_active (snapshot.active);
                    }
                    else if (snapshot.active) {
                        snapshot.watch.trigger ();
                    }
                }

                this.notify_property ("current-state-flags");
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            this.update_current_state_flags ();
        }

        public uint add_watch (Pomodoro.StateFlags          condition,
                               Pomodoro.StateFlags          precondition,
                               Pomodoro.EnterStateCallback? enter_state_callback,
                               Pomodoro.LeaveStateCallback? leave_state_callback = null)
        {
            if (condition == Pomodoro.StateFlags.NONE) {
                return 0;
            }

            var watch_id = Pomodoro.StateMonitor.next_watch_id;
            Pomodoro.StateMonitor.next_watch_id++;

            var watch = new Watch ();
            watch.condition = condition;
            watch.precondition = precondition;
            watch.enter_state_callback = enter_state_callback;
            watch.leave_state_callback = leave_state_callback;

            unowned Watch unowned_watch = watch;

            this.watches.insert ((int64) watch_id, (owned) watch);

            if (unowned_watch.is_stateful ()) {
                unowned_watch.set_active (unowned_watch.check (this._current_state_flags, this._current_state_flags));
            }

            return watch_id;
        }

        public void remove_watch (uint id)
        {
            unowned Watch? watch = this.watches.lookup ((int64) id);

            if (watch == null) {
                return;
            }

            if (watch.is_stateful ()) {
                watch.set_active (false);
            }

            this.watches.remove ((int64) id);
        }

        public override void dispose ()
        {
            this.timer.state_changed.disconnect (this.on_timer_state_changed);

            if (this.watches != null)
            {
            	foreach (unowned Watch watch in this.watches.get_values ())
        	    {
                    if (watch.is_stateful ()) {
                        watch.set_active (false);
                    }
	            }

                this.watches = null;
            }

            base.dispose ();
        }
    }
}
