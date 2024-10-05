using GLib;


namespace Pomodoro
{
    private bool trigger_start_event (Pomodoro.TimerState current_state,
                                      Pomodoro.TimerState previous_state)
    {
        if (Pomodoro.Context.get_event_source () != "timer.start") {
            return false;
        }

        return current_state.user_data != null && previous_state.user_data == null;
    }

    private bool trigger_stop_event (Pomodoro.TimerState current_state,
                                     Pomodoro.TimerState previous_state)
    {
        if (Pomodoro.Context.get_event_source () != "timer.reset") {
            return false;
        }

        return current_state.user_data == null && previous_state.user_data != null;
    }

    private bool trigger_pause_event (Pomodoro.TimerState current_state,
                                      Pomodoro.TimerState previous_state)
    {
        if (Pomodoro.Context.get_event_source () != "timer.pause") {
            return false;
        }

        return current_state.user_data == previous_state.user_data &&
               current_state.is_paused () && !previous_state.is_paused ();
    }

    private bool trigger_resume_event (Pomodoro.TimerState current_state,
                                       Pomodoro.TimerState previous_state)
    {
        if (Pomodoro.Context.get_event_source () != "timer.resume") {
            return false;
        }

        return current_state.user_data == previous_state.user_data &&
               !current_state.is_paused () && previous_state.is_paused ();
    }

    private bool trigger_rewind_event (Pomodoro.TimerState current_state,
                                       Pomodoro.TimerState previous_state)
    {
        if (Pomodoro.Context.get_event_source () != "timer.rewind") {
            return false;
        }

        return current_state.user_data == previous_state.user_data &&
               current_state.paused_time == previous_state.paused_time &&
               current_state.offset != previous_state.offset;
    }

    private bool trigger_skip_event (Pomodoro.Session?   current_session,
                                     Pomodoro.TimeBlock? current_time_block,
                                     Pomodoro.Session?   previous_session,
                                     Pomodoro.TimeBlock? previous_time_block)
    {
        if (Pomodoro.Context.get_event_source () != "session-manager.advance") {
            return false;
        }

        if (current_time_block == null || previous_time_block == null) {
            return false;
        }

        if (current_time_block.state != Pomodoro.State.POMODORO &&
            previous_time_block.state != Pomodoro.State.POMODORO)
        {
            return false;
        }

        if (current_time_block.state.is_break () == previous_time_block.state.is_break ()) {
            return false;
        }

        return current_time_block.get_status () == Pomodoro.TimeBlockStatus.IN_PROGRESS &&
               previous_time_block.get_status () == Pomodoro.TimeBlockStatus.UNCOMPLETED;
    }

    private bool trigger_reset_event (Pomodoro.Session?   current_session,
                                      Pomodoro.TimeBlock? current_time_block,
                                      Pomodoro.Session?   previous_session,
                                      Pomodoro.TimeBlock? previous_time_block)
    {
        if (Pomodoro.Context.get_event_source () != "session-manager.reset") {
            return false;
        }

        if (current_session == previous_session || previous_session == null) {
            return false;
        }

        if (current_session == null) {
            return true;
        }

        return !previous_session.is_completed ();
    }

    private bool trigger_finish_event (Pomodoro.TimerState current_state,
                                       Pomodoro.TimerState previous_state)
    {
        return current_state.is_finished () && !previous_state.is_finished ();
    }

    private bool trigger_confirm_advancement_event (Pomodoro.TimeBlock next_time_block,
                                                    Pomodoro.TimeBlock previous_time_block)
    {
        return true;
    }

    private bool trigger_advance_event (Pomodoro.Session?   current_session,
                                        Pomodoro.TimeBlock? current_time_block,
                                        Pomodoro.Session?   previous_session,
                                        Pomodoro.TimeBlock? previous_time_block)
    {
        // Internally `SessionManager.advanced` includes a stopped state, as it follows the call to `advance_*`
        // methods. For user this behaviour may not be obvious. The second thing is that it would intersect with
        // `start` and `stop` events. It makes more sense to have `start`, `stop` and `advance` events
        // complementary.

        return current_time_block != null && previous_time_block != null;
    }

    private bool trigger_change_event (Pomodoro.TimerState current_state,
                                       Pomodoro.TimerState previous_state)
    {
        // If timer finishes no true change has been done - the timer finished according to plan.
        if (current_state.is_finished () && current_state.user_data == previous_state.user_data) {
            return false;
        }

        return !current_state.equals (previous_state);
    }

    private bool trigger_state_change_event (Pomodoro.State current_state,
                                             Pomodoro.State previous_state)
    {
        return true;
    }

    private bool trigger_reschedule_event (Pomodoro.Session session)
    {
        return true;
    }

    private bool trigger_expire_event (Pomodoro.Session session)
    {
        return true;
    }


    public enum EventCategory
    {
        OTHER,
        ACTIONS,
        COUNTDOWN,
        SESSION;

        public string get_label ()
        {
            switch (this)
            {
                case ACTIONS:
                    return _("Actions");

                case COUNTDOWN:
                    return _("Countdown");

                case SESSION:
                    return _("Session");

                case OTHER:
                    return _("Other");

                default:
                    assert_not_reached ();
            }
        }

        public static void @foreach (GLib.Func<Pomodoro.EventCategory> func)
        {
            func (ACTIONS);
            func (COUNTDOWN);
            func (SESSION);
            func (OTHER);
        }
    }


    public class EventSpec
    {
        public string                 name;
        public string                 display_name;
        public string                 description;
        public Pomodoro.EventCategory category;

        internal Pomodoro.Trigger[] triggers;

        public EventSpec (string                 name,
                          string                 display_name,
                          string                 description,
                          Pomodoro.EventCategory category = Pomodoro.EventCategory.OTHER)
        {
            this.name = name;
            this.display_name = display_name;
            this.description = description;
            this.category = category;
            this.triggers = new Pomodoro.Trigger[0];
        }

        public void add_trigger (Pomodoro.TriggerHook trigger_hook,
                                 Pomodoro.TriggerFunc trigger_func)
        {
            unowned var self = this;

            this.triggers += Pomodoro.Trigger () {
                event_spec = self,
                hook       = trigger_hook,
                func       = trigger_func
            };
        }
    }


    [Compact]
    public class Event
    {
        public Pomodoro.EventSpec spec;
        public Pomodoro.Context           context;

        public Event (Pomodoro.EventSpec spec,
                      Pomodoro.Context   context)
        {
            this.spec = spec;
            this.context = context;
        }
    }


    internal void initialize_events (Pomodoro.EventProducer producer)
    {
        Pomodoro.EventSpec event_spec;

        // Actions
        event_spec = new Pomodoro.EventSpec ("start",
                                             _("Start"),
                                             _("Started the timer."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_start_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("stop",
                                             _("Stop"),
                                             _("Stopped the timer manually."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_stop_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("pause",
                                             _("Pause"),
                                             _("The countdown has been manually paused. Not triggered when locking the screen or when suspending the system."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_pause_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("resume",
                                             _("Resume"),
                                             _("The countdown has been manually resumed."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_resume_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("skip",
                                             _("Skip"),
                                             _("Jumped to a next time-block before the countdown has finished."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.SESSION_MANAGER_ADVANCED,
                                (Pomodoro.TriggerFunc) trigger_skip_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("rewind",
                                             _("Rewind"),
                                             _("Rewind action has been used. It adds a pause in the past."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_rewind_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("reset",
                                             _("Reset"),
                                             _("Manually cleared the session."),
                                             Pomodoro.EventCategory.ACTIONS);
        event_spec.add_trigger (Pomodoro.TriggerHook.SESSION_MANAGER_ADVANCED,
                                (Pomodoro.TriggerFunc) trigger_reset_event);
        producer.install_event (event_spec);

        // Countdown
        event_spec = new Pomodoro.EventSpec ("finish",
                                             _("Finished"),
                                             _("The countdown has finished. If waiting for confirmation, the duration of the time-block still may be altered."),
                                             Pomodoro.EventCategory.COUNTDOWN);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_finish_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("change",
                                             _("Changed"),
                                             _("Triggered on any change related to the countdown."),
                                             Pomodoro.EventCategory.COUNTDOWN);
        event_spec.add_trigger (Pomodoro.TriggerHook.TIMER_STATE_CHANGED,
                                (Pomodoro.TriggerFunc) trigger_change_event);
        producer.install_event (event_spec);

        // Session
        event_spec = new Pomodoro.EventSpec ("confirm-advancement",
                                             _("Confirm Advancement"),
                                             _("A manual confirmation is required to start next time-block."),
                                             Pomodoro.EventCategory.SESSION);
        event_spec.add_trigger (Pomodoro.TriggerHook.SESSION_MANAGER_CONFIRM_ADVANCEMENT,
                                (Pomodoro.TriggerFunc) trigger_confirm_advancement_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("advance",
                                             _("Advanced"),
                                             _("Transitioned or skipped to a next time-block."),
                                             Pomodoro.EventCategory.SESSION);
        event_spec.add_trigger (Pomodoro.TriggerHook.SESSION_MANAGER_ADVANCED,
                                (Pomodoro.TriggerFunc) trigger_advance_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("state-change",
                                             _("State Changed"),
                                             _("Transitioned to a next time-block or when a break gets relabelled."),
                                             Pomodoro.EventCategory.SESSION);
        event_spec.add_trigger (Pomodoro.TriggerHook.SESSION_MANAGER_NOTIFY_CURRENT_STATE,
                                (Pomodoro.TriggerFunc) trigger_state_change_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("reschedule",
                                             _("Rescheduled"),
                                             _("Triggered on any change related to the session."),
                                             Pomodoro.EventCategory.SESSION);
        event_spec.add_trigger (Pomodoro.TriggerHook.SCHEDULER_RESCHEDULED_SESSION,
                                (Pomodoro.TriggerFunc) trigger_reschedule_event);
        producer.install_event (event_spec);

        event_spec = new Pomodoro.EventSpec ("expire",
                                             _("Expired"),
                                             _("Triggered when session is about to be reset due to inactivity."),
                                             Pomodoro.EventCategory.SESSION);
        event_spec.add_trigger (Pomodoro.TriggerHook.SESSION_MANAGER_SESSION_EXPIRED,
                                (Pomodoro.TriggerFunc) trigger_expire_event);
        producer.install_event (event_spec);
    }
}
