namespace Pomodoro
{
    public interface ExpressionWidget : Gtk.Widget
    {
        public abstract Pomodoro.Expression? expression { get; set; }

        public abstract bool removable { get; set; }

        public signal void request_remove ();
    }


    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/condition-group-widget.ui")]
    public class ConditionGroupWidget : Gtk.Widget, Pomodoro.ExpressionWidget
    {
        private const int BRACKET_WIDTH = 24;
        private const int MIN_BRACKET_HEIGHT = 20;
        private const int MIN_WIDTH = 300;
        private const int NAT_WIDTH = 300;
        private const int PADDING = 0;
        private const int INDENT = 60;
        private const int SPACING = 6;
        private const float LINE_WIDTH = 2.0f;

        [CCode (notify = false)]
        public Pomodoro.Expression? expression {
            get {
                return (Pomodoro.Expression?) this._operation;
            }
            set {
                var operation = value as Pomodoro.Operation;

                if (this._operation == operation) {
                    return;
                }

                if (operation != null) {
                    this._operation = operation;
                    this._operator = operation.operator;
                }
                else {
                    this._operation = null;
                }

                this.notify_property ("expression");
                this.notify_property ("operator");

                this.populate ();
            }
        }

        public Pomodoro.Operator operator {
            get {
                return this._operator;
            }
            set {
                if (this._operator == value) {
                    return;
                }

                this._operator = value;

                if (this._operation != null) {
                    this._operation.operator = value;
                }

                this.update_operator_label ();
            }
        }

        public bool removable {
            get {
                return this._removable;
            }
            set {
                if (this._removable == value) {
                    return;
                }

                this._removable = value;

                this.update_remove_buttons ();
            }
        }

        public bool is_nested { get; set; default = false; }

        private Pomodoro.Operation? _operation = null;
        private Pomodoro.Operator   _operator = Pomodoro.Operator.AND;
        private bool                _removable = false;

        [GtkChild]
        private unowned Gtk.Button operator_button;
        [GtkChild]
        private unowned Gtk.Box arguments_box;
        [GtkChild]
        private unowned Gtk.Box buttons_box;

        private weak Pomodoro.Gizmo? top_bracket;
        private weak Pomodoro.Gizmo? bottom_bracket;

        static construct
        {
            set_css_name ("conditiongroup");
        }

        construct
        {
            var top_bracket = new Pomodoro.Gizmo (this.measure_bracket_child,
                                                  null,
                                                  this.snapshot_top_bracket,
                                                  null,
                                                  null,
                                                  null);
            top_bracket.focusable = false;
            top_bracket.set_parent (this);

            var bottom_bracket = new Pomodoro.Gizmo (this.measure_bracket_child,
                                                     null,
                                                     this.snapshot_bottom_bracket,
                                                     null,
                                                     null,
                                                     null);
            bottom_bracket.focusable = false;
            bottom_bracket.set_parent (this);

            this.top_bracket = top_bracket;
            this.bottom_bracket = bottom_bracket;

            this.populate ();
        }

        private Pomodoro.ExpressionWidget create_condition (Pomodoro.Expression? expression = null)
        {
            var child = new Pomodoro.ConditionWidget ();
            child.removable = true;
            child.expression = expression;
            child.notify["expression"].connect (this.on_argument_notify_expression);
            child.request_remove.connect (this.on_argument_request_remove);

            return (Pomodoro.ExpressionWidget) child;
        }

        private Pomodoro.ExpressionWidget create_condition_group (Pomodoro.Expression? expression = null)
        {
            var child = new Pomodoro.ConditionGroupWidget ();
            child.operator = this.operator != Pomodoro.Operator.AND
                ? Pomodoro.Operator.AND
                : Pomodoro.Operator.OR;
            child.removable = true;
            child.is_nested = true;
            child.request_remove.connect (this.on_argument_request_remove);

            return (Pomodoro.ExpressionWidget) child;
        }

        private void populate ()
        {
            var existing_arguments = new GLib.HashTable<string, Pomodoro.ExpressionWidget> (
                    GLib.str_hash, GLib.str_equal);

            this.foreach_argument (
                (argument) => {
                    var argument_key = argument.expression != null
                        ? ensure_string (argument.expression.to_string ())
                        : "";
                    existing_arguments.insert (argument_key, argument);

                    this.arguments_box.remove (argument);
                });

            var arguments_count = this._operation != null
                ? this._operation.arguments.length
                : 0;

            if (arguments_count == 0)
            {
                var argument = existing_arguments.lookup ("");

                if (argument == null) {
                    argument = this.create_condition ();
                }

                this.arguments_box.prepend (argument);
            }
            else {
                for (var index = 0; index < arguments_count; index++)
                {
                    var argument_expression = this._operation.arguments[index];
                    var argument_key = ensure_string (argument_expression?.to_string ());
                    var argument = existing_arguments.lookup (argument_key);

                    var operation = argument_expression as Pomodoro.Operation;
                    var is_condition_group =
                            operation != null &&
                            operation.operator.get_category () == Pomodoro.OperatorCategory.LOGICAL;

                    if (argument == null) {
                        argument = is_condition_group
                            ? this.create_condition_group (argument_expression)
                            : this.create_condition (argument_expression);
                    }
                    else {
                        existing_arguments.remove (argument_key);
                    }

                    this.arguments_box.insert_child_after (argument,
                                                           this.buttons_box.get_prev_sibling ());
                }
            }

            this.update_remove_buttons ();
            this.update_operator_label ();
        }

        private void foreach_argument (GLib.Func<Pomodoro.ExpressionWidget> func)
        {
            var child = this.arguments_box.get_first_child ();

            while (child != null)
            {
                var argument = child as Pomodoro.ExpressionWidget;
                var next_sibling = child.get_next_sibling ();

                if (argument != null) {
                    func (argument);
                }

                child = next_sibling;
            }
        }

        private bool is_empty ()
        {
            var arguments_count = 0;

            this.foreach_argument (
                (argument) => {
                    arguments_count++;
                });

            return arguments_count == 0;
        }

        private void update_remove_buttons ()
        {
            var arguments_count = 0;
            unowned Pomodoro.ExpressionWidget? first_argument = null;

            this.foreach_argument (
                (argument) => {
                    arguments_count++;

                    if (arguments_count == 1) {
                        first_argument = argument;
                    }
                    else {
                        argument.removable = true;
                    }
                });

            if (first_argument != null) {
                first_argument.removable = this.removable || this.is_nested || arguments_count > 1;
            }
        }

        private void update_operator_label ()
        {
            this.operator_button.label = this.operator == Pomodoro.Operator.AND
                ? _("AND")
                : _("OR");
        }

        private void update_expression ()
        {
            Pomodoro.Expression[] arguments = {};

            this.foreach_argument (
                (argument) => {
                    var argument_expression = argument.expression;
                    // TODO: validate that arguments are boolean

                    if (argument_expression != null) {
                        arguments += argument_expression;
                    }
                });

            this._operation = arguments.length > 0
                ? new Pomodoro.Operation.with_argv (this.operator, arguments)
                : null;

            this.notify_property ("expression");
        }

        private void measure_bracket_child (Pomodoro.Gizmo  gizmo,
                                            Gtk.Orientation orientation,
                                            int             for_size,
                                            out int         minimum,
                                            out int         natural,
                                            out int         minimum_baseline,
                                            out int         natural_baseline)
        {
            minimum = MIN_BRACKET_HEIGHT;
            natural = MIN_BRACKET_HEIGHT;
            minimum_baseline = 0;
            natural_baseline = 0;
        }

        private void snapshot_bracket (Pomodoro.Gizmo gizmo,
                                       Gtk.Snapshot   snapshot,
                                       bool           is_top)
        {
            var width           = (float) gizmo.get_width ();
            var height          = (float) gizmo.get_height ();
            var style_context   = gizmo.get_style_context ();
            var border_radius   = 8.0f;
            var padding = LINE_WIDTH / 2.0f;
            var x = width / 2.0f;
            var y = border_radius + padding;

            var color    = style_context.get_color ();
            color.alpha *= 0.2f;

            var path_builder = new Gsk.PathBuilder ();
            path_builder.move_to (x, height - padding);
            path_builder.line_to (x, y + border_radius);
            path_builder.quad_to (x, y, x + border_radius, y);
            path_builder.line_to (width - padding, y);

            var stroke = new Gsk.Stroke (LINE_WIDTH);
            stroke.set_line_cap (Gsk.LineCap.ROUND);

            if (!is_top) {
                snapshot.translate ({ 0.0f, height });
                snapshot.scale (1.0f, -1.0f);
            }

            snapshot.append_stroke (path_builder.to_path (), stroke, color);
        }

        private void snapshot_top_bracket (Pomodoro.Gizmo gizmo,
                                           Gtk.Snapshot   snapshot)
        {
            this.snapshot_bracket (gizmo, snapshot, true);
        }

        private void snapshot_bottom_bracket (Pomodoro.Gizmo gizmo,
                                              Gtk.Snapshot   snapshot)
        {
            this.snapshot_bracket (gizmo, snapshot, false);
        }

        private void on_argument_notify_expression (GLib.Object    object,
                                                    GLib.ParamSpec pspec)
        {
            this.update_expression ();
        }

        private void on_argument_request_remove (Pomodoro.ExpressionWidget argument)
        {
            this.arguments_box.remove ((Gtk.Widget) argument);

            if (!this.is_empty ()) {
                this.update_remove_buttons ();
                this.update_expression ();
            }
            else {
                if (this.is_nested) {
                    this.request_remove ();
                }
                else {
                    if (this._operation != null) {
                        this.expression = null;
                    }
                    else {
                        // The last child just got removed. Need to repopulate.
                        this.populate ();
                    }

                    if (this.removable) {
                        this.request_remove ();
                    }
                }
            }
        }

        [GtkCallback]
        private void on_operator_button_clicked (Gtk.Button button)
        {
            this.operator = this.operator == Pomodoro.Operator.AND
                ? Pomodoro.Operator.OR
                : Pomodoro.Operator.AND;
        }

        [GtkCallback]
        private void on_add_condition_button_clicked (Gtk.Button button)
        {
            var argument = this.create_condition ();
            var sibling = this.buttons_box.get_prev_sibling ();

            this.arguments_box.insert_child_after (argument, sibling);

            this.update_remove_buttons ();
        }

        [GtkCallback]
        private void on_add_condition_group_button_clicked (Gtk.Button button)
        {
            var argument = this.create_condition_group ();
            var sibling = this.buttons_box.get_prev_sibling ();

            this.arguments_box.insert_child_after (argument, sibling);

            this.update_remove_buttons ();
        }

        private void calculate_height_for_width (int     avaliable_width,
                                                 out int minimum_height,
                                                 out int natural_height)
        {
            var tmp_minimum_height = 0;
            var tmp_natural_height = 0;

            this.operator_button.measure (Gtk.Orientation.VERTICAL,
                                          INDENT,
                                          out tmp_minimum_height,
                                          out tmp_natural_height,
                                          null,
                                          null);
            minimum_height = tmp_minimum_height + 2 * MIN_BRACKET_HEIGHT;
            natural_height = tmp_natural_height + 2 * MIN_BRACKET_HEIGHT;

            if (avaliable_width >= 0)
            {
                this.arguments_box.measure (Gtk.Orientation.VERTICAL,
                                            avaliable_width - INDENT - SPACING,
                                            out tmp_minimum_height,
                                            out tmp_natural_height,
                                            null,
                                            null);
                minimum_height = int.max (minimum_height, tmp_minimum_height);
                natural_height = int.max (natural_height, tmp_natural_height);
            }
            else {
                this.arguments_box.measure (Gtk.Orientation.VERTICAL,
                                            MIN_WIDTH - INDENT - SPACING,
                                            out tmp_minimum_height,
                                            null,
                                            null,
                                            null);
                this.arguments_box.measure (Gtk.Orientation.VERTICAL,
                                            -1,
                                            null,
                                            out tmp_natural_height,
                                            null,
                                            null);
                minimum_height = int.max (minimum_height, tmp_minimum_height);
                natural_height = int.max (natural_height, tmp_natural_height);
            }
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            if (orientation == Gtk.Orientation.HORIZONTAL)
            {
                minimum = MIN_WIDTH;
                natural = for_size != -1
                    ? int.max (for_size, MIN_WIDTH)
                    : MIN_WIDTH;
            }
            else {
                this.calculate_height_for_width (for_size,
                                                 out minimum,
                                                 out natural);
            }

            if (natural < minimum) {
                natural = minimum;
            }

            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            // var is_ltr = this.get_direction () != Gtk.TextDirection.RTL;  // TODO

            var operator_allocation = Gtk.Allocation () {
                width = INDENT
            };
            this.operator_button.measure (Gtk.Orientation.VERTICAL,
                                          operator_allocation.width,
                                          null,
                                          out operator_allocation.height,
                                          null,
                                          null);

            var top_bracket_allocation = Gtk.Allocation () {
                x = (INDENT - BRACKET_WIDTH) / 2,
                y = 0,
                width = BRACKET_WIDTH,
                height = (height - operator_allocation.height - SPACING) / 2
            };

            var bottom_bracket_allocation = Gtk.Allocation () {
                x = top_bracket_allocation.x,
                y = height - top_bracket_allocation.height,
                width = top_bracket_allocation.width,
                height = top_bracket_allocation.height
            };

            var arguments_allocation = Gtk.Allocation () {
                width = width - INDENT - SPACING,
                height = height
            };
            this.arguments_box.measure (Gtk.Orientation.VERTICAL,
                                        arguments_allocation.width,
                                        null,
                                        out arguments_allocation.height,
                                        null,
                                        null);

            operator_allocation.x = INDENT - operator_allocation.width;
            arguments_allocation.x = operator_allocation.x + SPACING + operator_allocation.width;

            operator_allocation.y = (height - operator_allocation.height) / 2;
            arguments_allocation.y = (height - arguments_allocation.height) / 2;

            this.top_bracket.allocate_size (top_bracket_allocation, -1);
            this.operator_button.allocate_size (operator_allocation, -1);
            this.bottom_bracket.allocate_size (bottom_bracket_allocation, -1);
            this.arguments_box.allocate_size (arguments_allocation, -1);
        }
    }
}
