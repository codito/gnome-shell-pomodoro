namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/condition-widget.ui")]
    private class ConditionWidget : Gtk.Box, Pomodoro.ExpressionWidget
    {
        // NOTE: Keep choices synced with the .ui file.
        private const Pomodoro.Operator[] ENUM_OPERATOR_CHOICES = {
            Pomodoro.Operator.EQ,
            Pomodoro.Operator.NOT_EQ
        };
        private const Pomodoro.Operator[] NUMERICAL_OPERATOR_CHOICES = {
            Pomodoro.Operator.EQ,
            Pomodoro.Operator.GT,
            Pomodoro.Operator.LT
        };
        private const Pomodoro.State[] STATE_CHOICES = {
            Pomodoro.State.POMODORO,
            Pomodoro.State.BREAK,
            Pomodoro.State.STOPPED
        };
        private const bool[] BOOLEAN_CHOICES = {
            true,
            false
        };
        private const int64[] INTERVAL_UNIT_CHOICES = {
            Pomodoro.Interval.MINUTE,
            Pomodoro.Interval.SECOND,
            Pomodoro.Interval.HOUR
        };

        private class FieldItem : GLib.Object
        {
            public string name { get; construct; }
            public string label { get; construct; }
            public Pomodoro.VariableSpec? variable_spec { get; construct; }

            public FieldItem (string name, string label)
            {
                GLib.Object (
                    name: name,
                    label: label,
                    variable_spec: Pomodoro.find_variable (name)
                );
            }
        }

        /**
         * This widget can only represent `Comparison` expressions at the moment. It's possible
         * to extend it to handle more types of expressions, like using variables directly.
         */
        [CCode (notify = false)]
        public Pomodoro.Expression? expression
        {
            get {
                return (Pomodoro.Expression?) this._comparison;
            }
            set {
                var comparison = value as Pomodoro.Comparison;

                if (value != null && comparison == null) {
                    comparison = new Pomodoro.Comparison.is_true (value);
                }

                if (this._comparison == comparison) {
                    return;
                }

                this._comparison = comparison;
                this.populate ();

                this.notify_property ("expression");
            }
        }

        public bool removable { get; set; default = false; }

        [GtkChild]
        private unowned Gtk.FlowBox fields;
        [GtkChild]
        private unowned Gtk.DropDown field_dropdown;
        [GtkChild]
        private unowned Gtk.DropDown enum_operator_dropdown;
        [GtkChild]
        private unowned Gtk.DropDown numerical_operator_dropdown;
        [GtkChild]
        private unowned Gtk.DropDown state_dropdown;
        [GtkChild]
        private unowned Gtk.DropDown boolean_dropdown;
        [GtkChild]
        private unowned Gtk.SpinButton interval_spinbutton;
        [GtkChild]
        private unowned Gtk.DropDown interval_unit_dropdown;

        private Pomodoro.Comparison? _comparison = null;
        private uint                 update_idle_id = 0;

        static construct
        {
            set_css_name ("condition");
        }

        construct
        {
            var fields_list = new GLib.ListStore (typeof (FieldItem));
            fields_list.splice (0, 0, {
                /* translators: No field selected when defining a condition. */
                new FieldItem ("", _("Select Field…")),
                new FieldItem ("state", _("State")),
                new FieldItem ("is-started", _("Started")),
                new FieldItem ("is-paused", _("Paused")),
                new FieldItem ("is-running", _("Running")),
                new FieldItem ("is-finished", _("Finished")),
                new FieldItem ("duration", _("Duration")),
                // TODO: status, elapsed, remaining, offset?
            });
            this.field_dropdown.expression = new Gtk.PropertyExpression (
                typeof (FieldItem), null, "label");
            this.field_dropdown.model = fields_list;

            this.update_operator_fields ();
            this.update_value_fields ();

            /**
             * TODO: Having each field in it's own .ui file + constructing them dynamically
             *       would be a cleaner approach.
             */
            Gtk.Widget[] fields = {
                this.field_dropdown,
                this.enum_operator_dropdown,
                this.numerical_operator_dropdown,
                this.state_dropdown,
                this.boolean_dropdown,
                this.interval_spinbutton,
                this.interval_unit_dropdown,
            };

            foreach (var field in fields) {
                field.@ref ();
            }

            this.fields.remove_all ();
            this.fields.append (this.field_dropdown);
        }

        private static int64 guess_interval_unit (int64 interval)
        {
            if (interval % Pomodoro.Interval.HOUR == 0) {
                return Pomodoro.Interval.HOUR;
            }

            if (interval % Pomodoro.Interval.MINUTE == 0) {
                return Pomodoro.Interval.MINUTE;
            }

            return Pomodoro.Interval.SECOND;
        }

        private FieldItem? get_selected_field_item ()
        {
            var field_item = this.field_dropdown.selected_item as FieldItem;

            return field_item != null && field_item.name != "" ? field_item : null;
        }

        private Pomodoro.Operator get_selected_operator ()
        {
            if (this.enum_operator_dropdown.parent != null)
            {
                var index = this.enum_operator_dropdown.selected;
                assert (index < ENUM_OPERATOR_CHOICES.length);

                return ENUM_OPERATOR_CHOICES[index];
            }

            if (this.numerical_operator_dropdown.parent != null)
            {
                var index = this.numerical_operator_dropdown.selected;
                assert (index < NUMERICAL_OPERATOR_CHOICES.length);

                return NUMERICAL_OPERATOR_CHOICES[index];
            }

            return Pomodoro.Operator.EQ;
        }

        private Pomodoro.Value? get_selected_value ()
        {
            if (this.state_dropdown.parent != null)
            {
                var index = this.state_dropdown.selected;
                assert (index < STATE_CHOICES.length);

                return new Pomodoro.StateValue (STATE_CHOICES[index]);
            }

            if (this.boolean_dropdown.parent != null)
            {
                var index = this.boolean_dropdown.selected;
                assert (index < BOOLEAN_CHOICES.length);

                return new Pomodoro.BooleanValue (BOOLEAN_CHOICES[index]);
            }

            if (this.interval_spinbutton.parent != null)
            {
                var index = this.interval_unit_dropdown.selected;
                assert (index < INTERVAL_UNIT_CHOICES.length);

                var interval = Pomodoro.Interval.from_value ((int) this.interval_spinbutton.value,
                                                             INTERVAL_UNIT_CHOICES[index]);
                return new Pomodoro.IntervalValue (interval);
            }

            return null;
        }

        private void update_expression ()
        {
            var selected_field_item = this.get_selected_field_item ();
            var selected_operator = this.get_selected_operator ();
            var selected_value = this.get_selected_value ();

            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            if (selected_field_item != null &&
                selected_field_item?.name != null &&
                selected_value != null)
            {
                this._comparison = new Pomodoro.Comparison (
                    new Pomodoro.Variable (selected_field_item.name),
                    selected_operator,
                    new Pomodoro.Constant (selected_value)
                );
            }
            else
            {
                this._comparison = null;
            }

            this.notify_property ("expression");
        }

        private void queue_update_expression ()
        {
            if (this.update_idle_id != 0) {
                return;
            }

            this.update_idle_id = this.add_tick_callback (() => {
                this.update_idle_id = 0;

                this.update_expression ();

                return GLib.Source.REMOVE;
            });
        }

        private bool select_field (string name)
        {
            var fields_list = this.field_dropdown.model;
            var n_items = fields_list.get_n_items ();

            for (var position = 0; position < n_items; position++)
            {
                var item = (FieldItem) fields_list.get_item (position);

                if (item.name == name) {
                    this.field_dropdown.selected = position;
                    return true;
                }
            }

            return false;
        }

        private bool select_operator (Pomodoro.Operator operator)
        {
            if (this.enum_operator_dropdown.parent != null)
            {
                for (var index = 0; index < ENUM_OPERATOR_CHOICES.length; index++)
                {
                    if (ENUM_OPERATOR_CHOICES[index] == operator) {
                        this.enum_operator_dropdown.selected = index;
                        return true;
                    }
                }
            }

            if (this.numerical_operator_dropdown.parent != null)
            {
                for (var index = 0; index < NUMERICAL_OPERATOR_CHOICES.length; index++)
                {
                    if (NUMERICAL_OPERATOR_CHOICES[index] == operator) {
                        this.numerical_operator_dropdown.selected = index;
                        return true;
                    }
                }
            }

            return false;
        }

        private bool select_value (Pomodoro.Value? value)
        {
            if (value is Pomodoro.StateValue)
            {
                var state_value = ((Pomodoro.StateValue) value).data;

                for (var index = 0; index < STATE_CHOICES.length; index++)
                {
                    if (STATE_CHOICES[index] == state_value) {
                        this.state_dropdown.selected = index;
                        return true;
                    }
                }

                assert_not_reached ();
            }

            if (value is Pomodoro.BooleanValue)
            {
                var boolean_value = ((Pomodoro.BooleanValue) value).data;

                for (var index = 0; index < BOOLEAN_CHOICES.length; index++)
                {
                    if (BOOLEAN_CHOICES[index] == boolean_value) {
                        this.boolean_dropdown.selected = index;
                        return true;
                    }
                }

                assert_not_reached ();
            }

            if (value is Pomodoro.IntervalValue)
            {
                var interval_value = ((Pomodoro.IntervalValue) value).data;
                var interval_unit = guess_interval_unit (interval_value);

                interval_value /= interval_unit;

                for (var index = 0; index < INTERVAL_UNIT_CHOICES.length; index++)
                {
                    if (INTERVAL_UNIT_CHOICES[index] == interval_unit) {
                        this.interval_spinbutton.value = (double) interval_value;
                        this.interval_unit_dropdown.selected = index;
                        return true;
                    }
                }

                assert_not_reached ();
            }

            return false;
        }

        private void populate ()
        {
            if (this._comparison != null)
            {
                var argument_lhs = this._comparison.argument_lhs as Pomodoro.Variable;
                var argument_rhs = this._comparison.argument_rhs as Pomodoro.Constant;

                this.select_field (argument_lhs?.name);
                this.select_operator (this._comparison.operator);
                this.select_value (argument_rhs?.value);

                this.update_operator_fields ();
                this.update_value_fields ();
            }
        }

        private void update_empty_item ()
        {
            var selected_field_item = this.get_selected_field_item ();

            if (selected_field_item == null || selected_field_item.name == "") {
                return;
            }

            // TODO: Wrap model with Gtk.FilterListModel and toggle
            //       first item on and off.

            var model = (GLib.ListStore) this.field_dropdown.model;
            var first_item = (FieldItem) model.get_item (0);

            if (first_item.name == "") {
                model.remove (0);
            }
        }

        private void update_operator_fields ()
        {
            var selected_field_item = this.get_selected_field_item ();
            var selected_operator = this.get_selected_operator ();
            var value_type = selected_field_item != null
                ? (GLib.Type?) selected_field_item.variable_spec.value_type
                : (GLib.Type?) null;

            if (this.enum_operator_dropdown.parent != null) {
                this.fields.remove (this.enum_operator_dropdown);
            }

            if (this.numerical_operator_dropdown.parent != null) {
                this.fields.remove (this.numerical_operator_dropdown);
            }

            if (value_type == typeof (Pomodoro.StateValue)) {
                this.fields.insert (this.enum_operator_dropdown, 1);
            }

            if (value_type == typeof (Pomodoro.IntervalValue)) {
                this.fields.insert (this.numerical_operator_dropdown, 1);
            }

            if (!this.select_operator (selected_operator)) {
                this.enum_operator_dropdown.selected = 0;
                this.numerical_operator_dropdown.selected = 0;
            }

            this.queue_update_expression ();
        }

        private void update_value_fields ()
        {
            var selected_field_item = this.get_selected_field_item ();
            var selected_value = this.get_selected_value ();
            var value_type = selected_field_item != null
                ? (GLib.Type?) selected_field_item.variable_spec.value_type
                : (GLib.Type?) null;

            if (this.state_dropdown.parent != null) {
                this.fields.remove (this.state_dropdown);
            }

            if (this.boolean_dropdown.parent != null) {
                this.fields.remove (this.boolean_dropdown);
            }

            if (this.interval_spinbutton.parent != null) {
                this.fields.remove (this.interval_spinbutton);
            }

            if (this.interval_unit_dropdown.parent != null) {
                this.fields.remove (this.interval_unit_dropdown);
            }

            if (value_type == typeof (Pomodoro.StateValue)) {
                this.fields.append (this.state_dropdown);
            }

            if (value_type == typeof (Pomodoro.BooleanValue)) {
                this.fields.append (this.boolean_dropdown);
            }

            if (value_type == typeof (Pomodoro.IntervalValue)) {
                this.fields.append (this.interval_spinbutton);
                this.fields.append (this.interval_unit_dropdown);
            }

            if (!this.select_value (selected_value)) {
                this.state_dropdown.selected = 0;
                this.boolean_dropdown.selected = 0;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_field_notify_selected_item (GLib.Object    object,
                                                    GLib.ParamSpec pspec)
        {
            if (this.field_dropdown.model == null) {
                return;  // Not initialized yet.
            }

            this.update_empty_item ();
            this.update_operator_fields ();
            this.update_value_fields ();
        }

        [GtkCallback]
        private void on_enum_operator_notify_selected_item (GLib.Object    object,
                                                            GLib.ParamSpec pspec)
        {
            if (this.enum_operator_dropdown.parent == null) {
                return;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_numerical_operator_notify_selected_item (GLib.Object    object,
                                                                 GLib.ParamSpec pspec)
        {
            if (this.numerical_operator_dropdown.parent == null) {
                return;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_state_notify_selected_item (GLib.Object    object,
                                                    GLib.ParamSpec pspec)
        {
            if (this.state_dropdown.parent == null) {
                return;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_boolean_notify_selected_item (GLib.Object    object,
                                                      GLib.ParamSpec pspec)
        {
            if (this.boolean_dropdown.parent == null) {
                return;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_interval_adjustment_value_changed ()
        {
            if (this.interval_spinbutton.parent == null) {
                return;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_interval_unit_notify_selected_item (GLib.Object    object,
                                                            GLib.ParamSpec pspec)
        {
            if (this.interval_unit_dropdown.parent == null) {
                return;
            }

            this.queue_update_expression ();
        }

        [GtkCallback]
        private void on_remove_button_clicked (Gtk.Button button)
        {
            this.request_remove ();
        }

        public override void dispose ()
        {
            Gtk.Widget fields[] = {
                this.field_dropdown,
                this.enum_operator_dropdown,
                this.numerical_operator_dropdown,
                this.state_dropdown,
                this.boolean_dropdown,
                this.interval_spinbutton,
                this.interval_unit_dropdown,
            };

            if (this.update_idle_id != 0) {
                this.remove_tick_callback (this.update_idle_id);
                this.update_idle_id = 0;
            }

            foreach (var field in fields) {
                field.@unref ();
            }

            base.dispose ();
        }
    }
}
