namespace Pomodoro
{
    [CCode (has_target = false)]
    public delegate Pomodoro.Value EvaluateFunc (Pomodoro.Context context);


    public class VariableSpec
    {
        public string                name;
        public string                description;
        public GLib.Type             value_type;
        public Pomodoro.EvaluateFunc evaluate_func;

        public VariableSpec (string                      name,
                             string                      description,
                             GLib.Type                   value_type,
                             owned Pomodoro.EvaluateFunc evaluate_func)
        {
            this.name = name;
            this.description = description;
            this.value_type = value_type;
            this.evaluate_func = evaluate_func;
        }

        public inline Pomodoro.Value evaluate (Pomodoro.Context context)
                                               requires (this.evaluate_func != null)
        {
            return this.evaluate_func (context);
        }
    }


    private Pomodoro.VariableSpec[] variable_specs = null;
    private GLib.HashTable<string, unowned Pomodoro.VariableSpec> variable_spec_by_name = null;


    namespace Variables
    {
        private Pomodoro.Value get_timestamp (Pomodoro.Context context)
        {
            return new Pomodoro.TimestampValue (context.timestamp);
        }

        private Pomodoro.StateValue get_state (Pomodoro.Context context)
        {
            return new Pomodoro.StateValue (context.time_block != null
                                            ? context.time_block.state
                                            : Pomodoro.State.STOPPED);
        }

        private Pomodoro.StatusValue get_status (Pomodoro.Context context)
        {
            return new Pomodoro.StatusValue (context.time_block != null
                                             ? context.time_block.get_status ()
                                             : Pomodoro.TimeBlockStatus.SCHEDULED);
        }

        private Pomodoro.BooleanValue get_is_started (Pomodoro.Context context)
        {
            return new Pomodoro.BooleanValue (context.timer_state.is_started ());
        }

        private Pomodoro.BooleanValue get_is_paused (Pomodoro.Context context)
        {
            return new Pomodoro.BooleanValue (context.timer_state.is_paused ());
        }

        private Pomodoro.BooleanValue get_is_finished (Pomodoro.Context context)
        {
            return new Pomodoro.BooleanValue (context.timer_state.is_finished ());
        }

        private Pomodoro.BooleanValue get_is_running (Pomodoro.Context context)
        {
            return new Pomodoro.BooleanValue (context.timer_state.is_running ());
        }

        // private Pomodoro.BooleanValue get_is_enabled (Pomodoro.Context context)
        // {
        //     return new Pomodoro.BooleanValue (context.timer_state.is_enabled ());
        // }

        private Pomodoro.IntervalValue get_duration (Pomodoro.Context context)
        {
            return new Pomodoro.IntervalValue (context.timer_state.duration);
        }

        private Pomodoro.IntervalValue get_offset (Pomodoro.Context context)
        {
            return new Pomodoro.IntervalValue (context.timer_state.offset);
        }

        private Pomodoro.IntervalValue get_elapsed (Pomodoro.Context context)
        {
            return new Pomodoro.IntervalValue (context.timer_state.calculate_elapsed (context.timestamp));
        }

        private Pomodoro.IntervalValue get_remaining (Pomodoro.Context context)
        {
            return new Pomodoro.IntervalValue (context.timer_state.calculate_remaining (context.timestamp));
        }

        private Pomodoro.TimestampValue get_start_time (Pomodoro.Context context)
        {
            return new Pomodoro.TimestampValue (context.timer_state.started_time);
        }

        private void initialize ()
        {
            variable_specs = new Pomodoro.VariableSpec[0];
            variable_spec_by_name = new GLib.HashTable<string, unowned Pomodoro.VariableSpec> (GLib.str_hash, GLib.str_equal);

            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("timestamp",
                                           _("The exact time of the current event."),
                                           typeof (Pomodoro.TimestampValue),
                                           get_timestamp));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("state",
                                           _("The current phase of the Pomodoro cycle. Possible values: <tt>stopped</tt>, <tt>pomodoro</tt>, <tt>break</tt>, <tt>short-break</tt>, <tt>long-break</tt>."),
                                           typeof (Pomodoro.StateValue),
                                           get_state));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("status",
                                           _("Status of the current time-block. Possible values: <tt>scheduled</tt>, <tt>in-progress</tt>, <tt>completed</tt>, <tt>uncompleted</tt>."),
                                           typeof (Pomodoro.StatusValue),
                                           get_status));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("is-started",
                                           _("A flag indicating whether countdown has begun."),
                                           typeof (Pomodoro.BooleanValue),
                                           get_is_started));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("is-paused",
                                           _("A flag indicating whether countdown is paused."),
                                           typeof (Pomodoro.BooleanValue),
                                           get_is_paused));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("is-finished",
                                           _("A flag indicating whether countdown has finished."),
                                           typeof (Pomodoro.BooleanValue),
                                           get_is_finished));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("is-running",
                                           _("A flag indicating whether the timer is actively counting down."),
                                           typeof (Pomodoro.BooleanValue),
                                           get_is_running));
            // Pomodoro.install_variable (
            //     new Pomodoro.VariableSpec ("is-enabled",
            //                                _("A flag indicating whether the timer is enabled."),
            //                                typeof (Pomodoro.BooleanValue),
            //                                get_is_enabled));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("duration",
                                           _("Duration of the current countdown."),
                                           typeof (Pomodoro.IntervalValue),
                                           get_duration));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("offset",
                                           // _("Time lost that would otherwise be included in elapsed time."),
                                           _("Discrepancy between elapsed time and the time passed."),
                                           typeof (Pomodoro.IntervalValue),
                                           get_offset));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("elapsed",
                                           _("The amount of time spent on the countdown."),
                                           typeof (Pomodoro.IntervalValue),
                                           get_elapsed));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("remaining",
                                           _("The amount of time left before the countdown ends."),
                                           typeof (Pomodoro.IntervalValue),
                                           get_remaining));
            Pomodoro.install_variable (
                new Pomodoro.VariableSpec ("start-time",
                                           _("Time when the countdown has started."),
                                           typeof (Pomodoro.TimestampValue),
                                           get_start_time));
        }

        internal inline void ensure_initialized ()
        {
            if (variable_spec_by_name == null) {
                initialize ();
            }
        }
    }


    public void install_variable (Pomodoro.VariableSpec variable_spec)
    {
        variable_specs += variable_spec;
        variable_spec_by_name.insert (variable_spec.name, variable_spec);
    }

    public unowned Pomodoro.VariableSpec? find_variable (string variable_name)
    {
        Pomodoro.Variables.ensure_initialized ();

        return variable_spec_by_name.lookup (variable_name);
    }

    public (unowned Pomodoro.VariableSpec)[] list_variables ()
    {
        Pomodoro.Variables.ensure_initialized ();

        return variable_specs;
    }

    public bool find_variable_format (string variable_name,
                                      string variable_format)
    {
        if (variable_format == "") {
            return true;
        }

        var variable_spec = Pomodoro.find_variable (variable_name);

        if (variable_spec != null)
        {
            foreach (var format in Pomodoro.list_value_formats (variable_spec.value_type))
            {
                if (variable_format == format) {
                    return true;
                }
            }
        }

        return false;
    }
}
