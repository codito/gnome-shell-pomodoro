using GLib;


namespace Pomodoro
{
    public delegate void EventCallback (Pomodoro.Event event);
    public delegate void ConditionCallback (Pomodoro.Context context);


    [SingleInstance]
    public class EventBus : GLib.Object
    {
        [Compact]
        private class EventWatch
        {
            public uint                   id;
            public string                 event_name;
            public Pomodoro.Expression?   condition;
            public Pomodoro.EventCallback callback;

            public bool check_condition (Pomodoro.Context context)
            {
                if (this.condition == null) {
                    return true;
                }

                try {
                    var result = this.condition.evaluate (context);

                    return result != null ? result.to_boolean () : false;
                }
                catch (Pomodoro.ExpressionError error) {
                    GLib.warning ("Error while evaluating event condition: %s", error.message);
                    return false;
                }
            }
        }

        [Compact]
        private class ConditionWatch
        {
            public uint                        id;
            public Pomodoro.Expression         condition;
            public Pomodoro.ConditionCallback? enter_callback;
            public Pomodoro.ConditionCallback? leave_callback;
            public bool                        active = false;

            public void check_condition (Pomodoro.Context context)
            {
                var active = this.active;

                try {
                    var result = this.condition.evaluate (context);

                    active = result != null ? result.to_boolean () : false;
                }
                catch (Pomodoro.ExpressionError error) {
                    GLib.warning ("Error while evaluating condition: %s", error.message);
                    return;
                }

                if (this.active != active)
                {
                    if (this.active && this.leave_callback != null) {
                        this.leave_callback (context);
                    }

                    if (active && this.enter_callback != null) {
                        this.enter_callback (context);
                    }

                    this.active = active;
                }
            }
        }

        private static uint                          next_watch_id = 1;
        private Pomodoro.Context?                    last_context = null;
        private GLib.HashTable<uint, EventWatch>     event_watches = null;
        private GLib.HashTable<string, GLib.Array<unowned EventWatch>> event_watches_by_name = null;
        private GLib.HashTable<uint, ConditionWatch> condition_watches = null;
        private uint                                 check_conditions_idle_id = 0;

        construct
        {
            this.event_watches = new GLib.HashTable<uint, EventWatch> (
                    GLib.direct_hash, GLib.direct_equal);
            this.event_watches_by_name = new GLib.HashTable<string, GLib.Array<unowned EventWatch>> (
                    GLib.str_hash, GLib.str_equal);
            this.condition_watches = new GLib.HashTable<uint, ConditionWatch> (
                    GLib.direct_hash, GLib.direct_equal);
        }

        private void check_conditions (Pomodoro.Context context)
        {
            if (this.check_conditions_idle_id != 0) {
                GLib.Source.remove (this.check_conditions_idle_id);
                this.check_conditions_idle_id = 0;
            }

            if (context == this.last_context) {
                return;
            }

            this.condition_watches.@foreach (
                (id, watch) => {
                    watch.check_condition (context);
                });

            this.last_context = context;
        }

        private void schedule_check_conditions ()
        {
            if (this.check_conditions_idle_id != 0) {
                return;
            }

            this.check_conditions_idle_id = GLib.Idle.add (
                () => {
                    this.check_conditions_idle_id = 0;

                    this.check_conditions (new Pomodoro.Context.build ());

                    return GLib.Source.REMOVE;
                },
                GLib.Priority.DEFAULT
            );
            GLib.Source.set_name_by_id (this.check_conditions_idle_id,
                                        "Pomodoro.EventBus.check_conditions");
        }

        public void push_event (Pomodoro.Event event)
        {
            this.event (event);
        }

        public uint add_event_watch (string                       event_name,
                                     Pomodoro.Expression?         condition,
                                     owned Pomodoro.EventCallback callback)
        {
            var watch_id = Pomodoro.EventBus.next_watch_id;
            Pomodoro.EventBus.next_watch_id++;

            var watch = new EventWatch ();
            watch.id = watch_id;
            watch.event_name = event_name;
            watch.condition = condition;
            watch.callback = (owned) callback;

            unowned var unowned_watch = watch;
            unowned var unowned_watches_array = this.event_watches_by_name.lookup (event_name);

            this.event_watches.insert (watch_id, (owned) watch);

            if (unowned_watches_array == null)
            {
                var watches_array = new GLib.Array<unowned EventWatch> ();
                watches_array.append_val (unowned_watch);

                this.event_watches_by_name.insert (event_name, watches_array);
            }
            else {
                unowned_watches_array.append_val (unowned_watch);
            }

            return watch_id;
        }

        public uint add_condition_watch (Pomodoro.Expression               condition,
                                         owned Pomodoro.ConditionCallback? enter_callback,
                                         owned Pomodoro.ConditionCallback? leave_callback)
        {
            var watch_id = Pomodoro.EventBus.next_watch_id;
            Pomodoro.EventBus.next_watch_id++;

            var watch = new ConditionWatch ();
            watch.id = watch_id;
            watch.condition = condition;
            watch.enter_callback = (owned) enter_callback;
            watch.leave_callback = (owned) leave_callback;

            this.condition_watches.insert (watch_id, (owned) watch);

            this.schedule_check_conditions ();

            return watch_id;
        }

        public void remove_event_watch (uint watch_id)
        {
            unowned var watch = this.event_watches.lookup (watch_id);

            if (watch == null) {
                GLib.warning ("Unable to remove event watch %u.", watch_id);
                return;
            }

            unowned var watches_array = this.event_watches_by_name.lookup (watch.event_name);

            if (watches_array != null)
            {
                for (var index = 0U; index < watches_array.length; index++)
                {
                    unowned var item = watches_array.index (index);

                    if (item == watch) {
                        watches_array.remove_index (index);
                        break;
                    }
                }
            }

            this.event_watches.remove (watch_id);
        }

        public void remove_condition_watch (uint watch_id)
        {
            unowned var watch = this.condition_watches.lookup (watch_id);

            if (watch == null) {
                GLib.warning ("Unable to remove condition watch %u.", watch_id);
                return;
            }

            if (watch.active)
            {
                if (watch.leave_callback != null) {
                    watch.leave_callback (new Pomodoro.Context.build ());
                }

                watch.active = false;
            }

            this.condition_watches.remove (watch_id);
        }

        public void destroy ()
        {
            if (this.check_conditions_idle_id != 0) {
                GLib.Source.remove (this.check_conditions_idle_id);
                this.check_conditions_idle_id = 0;
            }

            var context = new Pomodoro.Context.build ();

            this.condition_watches.@foreach (
                (id, watch) => {
                    if (watch.active)
                    {
                        if (watch.leave_callback != null) {
                            watch.leave_callback (context);
                        }

                        watch.active = false;
                    }
                });
        }

        public signal void event (Pomodoro.Event event)
        {
            unowned var watches_array = this.event_watches_by_name.lookup (event.spec.name);

            if (watches_array != null)
            {
	            for (var index = 0U; index < watches_array.length; index++)
                {
                    unowned var watch = watches_array.index (index);

                    if (watch.check_condition (event.context)) {
                        watch.callback (event);
                    }
	            }
            }

            // TODO: Some events like "reschedule" are followed by an another, so there's little reason to check
            //       conditions again. Perhaps such events could have a flag.
            if (event.spec.name != "reschedule") {
                this.check_conditions (event.context);
            }
        }

        public override void dispose ()
        {
            this.destroy ();

            this.last_context = null;

            if (this.event_watches_by_name != null) {
                this.event_watches_by_name.remove_all ();
                this.event_watches_by_name = null;
            }

            if (this.event_watches != null) {
                this.event_watches.remove_all ();
                this.event_watches = null;
            }

            if (this.condition_watches != null) {
                this.condition_watches.remove_all ();
                this.condition_watches = null;
            }

            base.dispose ();
        }
    }
}
