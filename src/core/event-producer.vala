using GLib;


namespace Pomodoro
{
    [CCode (has_target = false)]
    public delegate bool TriggerFunc ();

    [CCode (has_target = false)]
    public delegate bool TimerStateChangedTriggerFunc (
                                       Pomodoro.TimerState current_state,
                                       Pomodoro.TimerState previous_state);

    [CCode (has_target = false)]
    public delegate bool SessionManagerConfirmAdvancementTriggerFunc (
                                       Pomodoro.TimeBlock next_time_block,
                                       Pomodoro.TimeBlock previous_time_block);

    [CCode (has_target = false)]
    public delegate bool SessionManagerAdvancedTriggerFunc (
                                       Pomodoro.Session?   current_session,
                                       Pomodoro.TimeBlock? current_time_block,
                                       Pomodoro.Session?   previous_session,
                                       Pomodoro.TimeBlock? previous_time_block);

    [CCode (has_target = false)]
    public delegate bool SessionManagerNotifyCurrentStateTriggerFunc (
                                       Pomodoro.State current_state,
                                       Pomodoro.State previous_state);

    [CCode (has_target = false)]
    public delegate bool SessionManagerSessionExpiredTriggerFunc (
                                       Pomodoro.Session current_session);

    [CCode (has_target = false)]
    public delegate bool SchedulerRescheduledSessionTriggerFunc (
                                       Pomodoro.Session session);


    public enum TriggerHook
    {
        NONE,
        TIMER_STATE_CHANGED,
        SESSION_MANAGER_CONFIRM_ADVANCEMENT,
        SESSION_MANAGER_ADVANCED,
        SESSION_MANAGER_NOTIFY_CURRENT_STATE,
        SESSION_MANAGER_SESSION_EXPIRED,
        SCHEDULER_RESCHEDULED_SESSION
    }


    public struct Trigger
    {
        public unowned Pomodoro.EventSpec   event_spec;
        public Pomodoro.TriggerHook         hook;
        public Pomodoro.TriggerFunc         func;
    }


    /**
     * Gathers events from various sources and pushes them onto a bus. It's not 1:1 mapping; events are supposed to be
     * more intuitive for the user. Some events are filtered to not trigger them unnecessarily, and some are delayed
     * to collect fuller context.
     */
    [SingleInstance]
    public class EventProducer : GLib.Object
    {
        public Pomodoro.SessionManager session_manager
        {
            get {
                return this._session_manager;
            }
            construct
            {
                this._session_manager = value;
                this._session_manager.confirm_advancement.connect (this.on_session_manager_confirm_advancement);
                this._session_manager.advanced.connect (this.on_session_manager_advanced);
                this._session_manager.notify["current-state"].connect (this.on_session_manager_notify_current_state);
                this._session_manager.session_expired.connect (this.on_session_manager_session_expired);

                this.previous_state = this._session_manager.current_state;
            }
        }

        public Pomodoro.Timer timer
        {
            get {
                return this._timer;
            }
            construct
            {
                this._timer = value;
                this._timer.state_changed.connect (this.on_timer_state_changed);
            }
        }

        public Pomodoro.Scheduler scheduler
        {
            get {
                return this._scheduler;
            }
            construct
            {
                this._scheduler = value;
                this._scheduler.rescheduled_session.connect (this.on_scheduler_rescheduled_session);
            }
        }

        public Pomodoro.EventBus bus
        {
            get {
                return this._bus;
            }
            construct {
                this._bus = value;
            }
        }

        private Pomodoro.SessionManager?                   _session_manager = null;
        private Pomodoro.Timer?                            _timer = null;
        private Pomodoro.Scheduler?                        _scheduler = null;
        private Pomodoro.EventBus?                         _bus = null;
        private Pomodoro.EventSpec[]                       event_specs = null;
        private GLib.HashTable<string, unowned Pomodoro.EventSpec> event_spec_by_name = null;
        private Pomodoro.State                             previous_state;
        private GLib.Queue<unowned Pomodoro.EventSpec>     queue = null;
        private uint                                       idle_id = 0;
        private int64                                      event_source_timestamp = Pomodoro.Timestamp.UNDEFINED;

        private Pomodoro.Trigger[]                         timer_state_change_triggers;
        private Pomodoro.Trigger[]                         session_manager_confirm_advancement_triggers;
        private Pomodoro.Trigger[]                         session_manager_advanced_triggers;
        private Pomodoro.Trigger[]                         session_manager_notify_current_state_triggers;
        private Pomodoro.Trigger[]                         session_manager_session_expired_triggers;
        private Pomodoro.Trigger[]                         scheduler_rescheduled_session_triggers;

        construct
        {
            this.event_specs = new Pomodoro.EventSpec[0];
            this.event_spec_by_name = new GLib.HashTable<string, unowned Pomodoro.EventSpec> (GLib.str_hash, GLib.str_equal);
            this.queue = new GLib.Queue<unowned Pomodoro.EventSpec> ();

            this.timer_state_change_triggers                   = new Pomodoro.Trigger[0];
            this.session_manager_confirm_advancement_triggers  = new Pomodoro.Trigger[0];
            this.session_manager_advanced_triggers             = new Pomodoro.Trigger[0];
            this.session_manager_notify_current_state_triggers = new Pomodoro.Trigger[0];
            this.session_manager_session_expired_triggers      = new Pomodoro.Trigger[0];
            this.scheduler_rescheduled_session_triggers        = new Pomodoro.Trigger[0];

            Pomodoro.initialize_events (this);
        }

        public EventProducer ()
        {
            var session_manager = Pomodoro.SessionManager.get_default ();
            var bus = new Pomodoro.EventBus ();

            GLib.Object (
                session_manager: session_manager,
                timer: session_manager.timer,
                scheduler: session_manager.scheduler,
                bus: bus
            );
        }

        public EventProducer.with_session_manager (Pomodoro.SessionManager session_manager)
        {
            var bus = new Pomodoro.EventBus ();

            GLib.Object (
                session_manager: session_manager,
                timer: session_manager.timer,
                scheduler: session_manager.scheduler,
                bus: bus
            );
        }

        public void install_event (Pomodoro.EventSpec event_spec)
        {
            unowned var unowned_event_spec = event_spec;

            foreach (var trigger in event_spec.triggers)
            {
                switch (trigger.hook)
                {
                    case Pomodoro.TriggerHook.TIMER_STATE_CHANGED:
                        this.timer_state_change_triggers += trigger;
                        break;

                    case Pomodoro.TriggerHook.SESSION_MANAGER_CONFIRM_ADVANCEMENT:
                        this.session_manager_confirm_advancement_triggers += trigger;
                        break;

                    case Pomodoro.TriggerHook.SESSION_MANAGER_ADVANCED:
                        this.session_manager_advanced_triggers += trigger;
                        break;

                    case Pomodoro.TriggerHook.SESSION_MANAGER_NOTIFY_CURRENT_STATE:
                        this.session_manager_notify_current_state_triggers += trigger;
                        break;

                    case Pomodoro.TriggerHook.SESSION_MANAGER_SESSION_EXPIRED:
                        this.session_manager_session_expired_triggers += trigger;
                        break;

                    case Pomodoro.TriggerHook.SCHEDULER_RESCHEDULED_SESSION:
                        this.scheduler_rescheduled_session_triggers += trigger;
                        break;

                    default:
                        assert_not_reached ();
                }
            }

            if (event_spec_by_name.insert (event_spec.name, unowned_event_spec)) {
                this.event_specs += event_spec;
            }
            else {
                GLib.error ("Unable to install event '%s'", event_spec.name);
            }
        }

        public unowned Pomodoro.EventSpec? find_event (string event_name)
        {
            return this.event_spec_by_name.lookup (event_name);
        }

        public (unowned Pomodoro.EventSpec)[] list_events ()
        {
            return this.event_specs;
        }

        private void trigger_queued_events (Pomodoro.Context context)
        {
            Pomodoro.EventSpec event_spec;

            if (this.idle_id != 0) {
                GLib.Source.remove (this.idle_id);
                this.idle_id = 0;
            }

	        while ((event_spec = this.queue.pop_head ()) != null)
            {
                this.event (new Pomodoro.Event (event_spec, context));
	        }
        }

        private void trigger_event (Pomodoro.EventSpec event_spec,
                                    int64              timestamp)
        {
            var context = new Pomodoro.Context.build (timestamp);

            this.trigger_queued_events (context);

            this.event (new Pomodoro.Event (event_spec, context));
        }

        private bool on_idle ()
        {
            var timestamp = this.event_source_timestamp;

            if (Pomodoro.Timestamp.is_undefined (timestamp))
            {
                timestamp = int64.max (this._timer.get_last_state_changed_time (),
                                       this._timer.get_last_tick_time ());
            }

            this.idle_id = 0;
            this.event_source_timestamp = Pomodoro.Timestamp.UNDEFINED;

            this.trigger_queued_events (new Pomodoro.Context.build (timestamp));

            return GLib.Source.REMOVE;
        }

        private void queue_event (Pomodoro.EventSpec event_spec)
        {
            // TODO: preserve event current timestamp, for the context
            this.queue.push_tail (event_spec);

            this.event_source_timestamp = Pomodoro.Context.get_event_source_timestamp ();

            if (this.idle_id == 0) {
                this.idle_id = GLib.Idle.add (this.on_idle, GLib.Priority.DEFAULT);
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState current_state,
                                             Pomodoro.TimerState previous_state)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            foreach (var trigger in this.timer_state_change_triggers)
            {
                var trigger_func = (Pomodoro.TimerStateChangedTriggerFunc) trigger.func;

                if (trigger_func (current_state, previous_state)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_session_manager_confirm_advancement (Pomodoro.TimeBlock current_time_block,
                                                             Pomodoro.TimeBlock next_time_block)
        {
            var timestamp = current_time_block.end_time;

            foreach (var trigger in this.session_manager_confirm_advancement_triggers)
            {
                var trigger_func = (Pomodoro.SessionManagerConfirmAdvancementTriggerFunc) trigger.func;

                if (trigger_func (current_time_block, next_time_block)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_session_manager_advanced (Pomodoro.Session?   current_session,
                                                  Pomodoro.TimeBlock? current_time_block,
                                                  Pomodoro.Session?   previous_session,
                                                  Pomodoro.TimeBlock? previous_time_block)
        {
            var timestamp = this._timer.get_last_state_changed_time ();

            if (previous_time_block != null) {
                timestamp = previous_time_block.end_time;
            }

            if (current_time_block != null) {
                timestamp = current_time_block.start_time;
            }

            foreach (var trigger in this.session_manager_advanced_triggers)
            {
                var trigger_func = (Pomodoro.SessionManagerAdvancedTriggerFunc) trigger.func;

                if (trigger_func (current_session, current_time_block, previous_session, previous_time_block)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_session_manager_notify_current_state (GLib.Object    object,
                                                             GLib.ParamSpec pspec)
        {
            var current_state = this._session_manager.current_state;
            var previous_state = this.previous_state;

            if (current_state == previous_state) {
                return;
            }

            this.previous_state = current_state;

            foreach (var trigger in this.session_manager_notify_current_state_triggers)
            {
                var trigger_func = (Pomodoro.SessionManagerNotifyCurrentStateTriggerFunc) trigger.func;

                if (trigger_func (current_state, previous_state)) {
                    this.queue_event (trigger.event_spec);
                }
            }
        }

        private void on_session_manager_session_expired (Pomodoro.Session session)
        {
            var timestamp = session.end_time;

            foreach (var trigger in this.session_manager_session_expired_triggers)
            {
                var trigger_func = (Pomodoro.SessionManagerSessionExpiredTriggerFunc) trigger.func;

                if (trigger_func (session)) {
                    this.trigger_event (trigger.event_spec, timestamp);
                }
            }
        }

        private void on_scheduler_rescheduled_session (Pomodoro.Session session)
        {
            foreach (var trigger in this.scheduler_rescheduled_session_triggers)
            {
                var trigger_func = (Pomodoro.SchedulerRescheduledSessionTriggerFunc) trigger.func;

                if (trigger_func (session)) {
                    // A reschedule is typically done as first thing before any action.
                    // To capture timer context we need to to delay collecting the context.
                    this.queue_event (trigger.event_spec);
                }
            }
        }

        [Signal (run = "first")]
        public signal void event (Pomodoro.Event event)
        {
            this._bus.push_event (event);
        }

        public override void dispose ()
        {
            if (this.idle_id != 0) {
                GLib.Source.remove (this.idle_id);
                this.idle_id = 0;
            }

            if (this.event_spec_by_name != null) {
                this.event_spec_by_name.remove_all ();
            }

            if (this._timer != null) {
                this._timer.state_changed.disconnect (this.on_timer_state_changed);
                this._timer = null;
            }

            if (this._session_manager != null) {
                this._session_manager.confirm_advancement.disconnect (this.on_session_manager_confirm_advancement);
                this._session_manager.advanced.disconnect (this.on_session_manager_advanced);
                this._session_manager.notify["current-state"].disconnect (this.on_session_manager_notify_current_state);
                this._session_manager.session_expired.disconnect (this.on_session_manager_session_expired);
                this._session_manager = null;
            }

            if (this._scheduler != null) {
                this._scheduler.rescheduled_session.disconnect (this.on_scheduler_rescheduled_session);
                this._scheduler = null;
            }

            this._bus = null;
            this.event_specs = null;
            this.event_spec_by_name = null;
            this.queue = null;
            this.event_source_timestamp = Pomodoro.Timestamp.UNDEFINED;

            this.timer_state_change_triggers = null;
            this.session_manager_confirm_advancement_triggers = null;
            this.session_manager_advanced_triggers = null;
            this.session_manager_notify_current_state_triggers = null;
            this.session_manager_session_expired_triggers = null;
            this.scheduler_rescheduled_session_triggers = null;

            base.dispose ();
        }
    }
}
