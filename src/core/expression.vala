using GLib;


namespace Pomodoro
{
    private inline string quote_string (string text)
    {
        // TODO: escape quotes

        return @"\"$(text)\"";
    }


    public errordomain ExpressionError
    {
        EMPTY,
        VALUE,
        TYPE,
        INVALID
    }


    public enum OperatorCategory
    {
        LOGICAL,
        COMPARISON
    }


    /**
     * Operator takes two inputs and produces one output.
     *
     * By this definition a "NOT" operation would not be an operator, but a function.
     */
    public enum Operator
    {
        INVALID,

        // Logical
        AND,
        OR,

        // Comparison
        EQ,
        LT,
        LTE,
        GT,
        GTE,
        NOT_EQ;

        public Pomodoro.OperatorCategory get_category ()
        {
            switch (this)
            {
                case AND:
                case OR:
                    return Pomodoro.OperatorCategory.LOGICAL;

                case EQ:
                case LT:
                case LTE:
                case GT:
                case GTE:
                case NOT_EQ:
                    return Pomodoro.OperatorCategory.COMPARISON;

                default:
                    assert_not_reached ();
            }
        }

        internal uint get_precedence ()
        {
            switch (this)
            {
                case OR:
                    return 1;

                case AND:
                    return 2;

                case EQ:
                case LT:
                case LTE:
                case GT:
                case GTE:
                case NOT_EQ:
                    return 3;

                default:
                    assert_not_reached ();
            }
        }

        public static void @foreach (GLib.Func<Pomodoro.Operator> func)
        {
            Pomodoro.Operator[] operators = {
                AND,
                OR,
                EQ,
                LT,
                LTE,
                GT,
                GTE,
                NOT_EQ,
            };

            foreach (var operator in operators) {
                func (operator);
            }
        }

        private static inline Pomodoro.Value apply_and (Pomodoro.Value value_1,
                                                        Pomodoro.Value value_2)
        {
            return new Pomodoro.BooleanValue (value_1.to_boolean () && value_2.to_boolean ());
        }

        private static inline Pomodoro.Value apply_or (Pomodoro.Value value_1,
                                                       Pomodoro.Value value_2)
        {
            return new Pomodoro.BooleanValue (value_1.to_boolean () || value_2.to_boolean ());
        }

        public Pomodoro.Value apply (Pomodoro.Value value_1,
                                     Pomodoro.Value value_2)
                                     throws Pomodoro.ExpressionError
        {
            switch (this)
            {
                case AND:
                    return apply_and (value_1, value_2);

                case OR:
                    return apply_or (value_1, value_2);

                case EQ:
                    return value_1.apply_eq (value_2);

                case LT:
                    return value_1.apply_lt (value_2);

                case LTE:
                    return apply_or (value_1.apply_lt (value_2),
                                     value_1.apply_eq (value_2));

                case GT:
                    return value_1.apply_gt (value_2);

                case GTE:
                    return apply_or (value_1.apply_gt (value_2),
                                     value_1.apply_eq (value_2));

                case NOT_EQ:
                    return new Pomodoro.BooleanValue (!value_1.apply_eq (value_2).to_boolean ());

                default:
                    assert_not_reached ();
            }
        }

        public GLib.Type get_result_type (GLib.Type value_type_1,
                                          GLib.Type value_type_2)
        {
            switch (this.get_category ())
            {
                case Pomodoro.OperatorCategory.COMPARISON:
                    return typeof (Pomodoro.BooleanValue);

                case Pomodoro.OperatorCategory.LOGICAL:
                    return typeof (Pomodoro.BooleanValue);  // TODO: the result type should vary at runtime; make it work like in javascript

                default:
                    assert_not_reached ();
            }
        }

        public string to_string ()
        {
            switch (this)
            {
                case AND:
                    return "&&";

                case OR:
                    return "||";

                case EQ:
                    return "==";

                case LT:
                    return "<";

                case LTE:
                    return "<=";

                case GT:
                    return ">";

                case GTE:
                    return ">=";

                case NOT_EQ:
                    return "!=";

                default:
                    assert_not_reached ();
            }
        }
    }


    public abstract class Value
    {
        public abstract GLib.Type get_value_type ();

        public abstract string get_type_name ();

        public abstract bool to_boolean ();

        public abstract string to_representation ();

        public abstract GLib.Variant to_variant ();

        public virtual GLib.Variant format (string name) throws Pomodoro.ExpressionError
        {
            if (name != "") {
                throw new Pomodoro.ExpressionError.INVALID (_("Unknown format \"%s\""), name);
            }

            return this.to_variant ();
        }

        internal virtual Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                  throws Pomodoro.ExpressionError
        {
            throw new Pomodoro.ExpressionError.INVALID (
                "Comparison operation not supported for types '%s' and '%s'",  // TODO: gettext
                this.get_type_name (),
                other.get_type_name ());
        }

        internal virtual Pomodoro.Value apply_gt (Pomodoro.Value other)
                                                  throws Pomodoro.ExpressionError
        {
            throw new Pomodoro.ExpressionError.INVALID (
                "Relational operation not supported for types '%s' and '%s'",  // TODO: gettext
                this.get_type_name (),
                other.get_type_name ());
        }

        internal virtual Pomodoro.Value apply_lt (Pomodoro.Value other)
                                                  throws Pomodoro.ExpressionError
        {
            throw new Pomodoro.ExpressionError.INVALID (
                "Relational operation not supported for types '%s' and '%s'",  // TODO: gettext
                this.get_type_name (),
                other.get_type_name ());
        }
    }


    public class BooleanValue : Pomodoro.Value
    {
        public bool data;

        public BooleanValue (bool value)
        {
            this.data = value;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Pomodoro.BooleanValue);
        }

        public override string get_type_name ()
        {
            return "boolean";
        }

        public override bool to_boolean ()
        {
            return this.data;
        }

        public override string to_representation ()
        {
            return this.data.to_string ();
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.boolean (this.data);
        }

        internal override Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_boolean = other as Pomodoro.BooleanValue;
            if (other_boolean != null) {
                return new Pomodoro.BooleanValue (this.data == other_boolean.data);
            }

            return base.apply_eq (other);
        }
    }


    public class TimestampValue : Pomodoro.Value
    {
        public int64 data;

        public TimestampValue (int64 timestamp)
        {
            this.data = timestamp;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Pomodoro.TimestampValue);
        }

        public override string get_type_name ()
        {
            return "timestamp";
        }

        public override bool to_boolean ()
        {
            return Pomodoro.Timestamp.is_defined (this.data);
        }

        public override string to_representation ()
        {
            // TODO: figure out how to represent undefined timestamp; just use null?

            return quote_string (this.to_string ());
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.int64 (this.data);
        }

        public override GLib.Variant format (string name)
                                             throws Pomodoro.ExpressionError
        {
            switch (name)
            {
                case "iso8601":
                    return new GLib.Variant.string (Pomodoro.Timestamp.to_iso8601 (this.data));

                case "seconds":
                    return new GLib.Variant.double (Pomodoro.Timestamp.to_seconds (this.data));

                case "microseconds":
                    return this.to_variant ();

                default:
                    return base.format (name);
            }
        }

        private inline string to_string ()
        {
            return Pomodoro.Timestamp.to_iso8601 (this.data);
        }

        internal override Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_timestamp = other as Pomodoro.TimestampValue;
            if (other_timestamp != null) {
                return new Pomodoro.BooleanValue (this.data == other_timestamp.data);
            }

            var other_string = other as Pomodoro.StringValue;
            if (other_string != null) {
                return new Pomodoro.BooleanValue (this.to_string () == other_string.data);
            }

            return base.apply_eq (other);
        }

        internal override Pomodoro.Value apply_lt (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_timestamp = other as Pomodoro.TimestampValue;
            if (other_timestamp != null) {
                return new Pomodoro.BooleanValue (this.data < other_timestamp.data);
            }

            return base.apply_lt (other);
        }

        internal override Pomodoro.Value apply_gt (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_timestamp = other as Pomodoro.TimestampValue;
            if (other_timestamp != null) {
                return new Pomodoro.BooleanValue (this.data > other_timestamp.data);
            }

            return base.apply_gt (other);
        }
    }


    public class IntervalValue : Pomodoro.Value
    {
        public int64 data;

        public IntervalValue (int64 interval)
        {
            this.data = interval;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Pomodoro.IntervalValue);
        }

        public override string get_type_name ()
        {
            return "interval";
        }

        public override bool to_boolean ()
        {
            return this.data != 0;
        }

        public override string to_representation ()
        {
            return this.data.to_string ();
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.int64 (this.data);
        }

        public override GLib.Variant format (string name)
                                             throws Pomodoro.ExpressionError
        {
            switch (name)
            {
                case "minutes":
                    return new GLib.Variant.double (
                        Pomodoro.Timestamp.to_seconds (this.data) / 60.0);

                case "seconds":
                    return new GLib.Variant.double (Pomodoro.Timestamp.to_seconds (this.data));

                case "microseconds":
                    return this.to_variant ();

                default:
                    return base.format (name);
            }
        }

        internal override Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_interval = other as Pomodoro.IntervalValue;
            if (other_interval != null) {
                return new Pomodoro.BooleanValue (this.data == other_interval.data);
            }

            return base.apply_eq (other);
        }

        internal override Pomodoro.Value apply_lt (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_interval = other as Pomodoro.IntervalValue;
            if (other_interval != null) {
                return new Pomodoro.BooleanValue (this.data < other_interval.data);
            }

            return base.apply_lt (other);
        }

        internal override Pomodoro.Value apply_gt (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_interval = other as Pomodoro.IntervalValue;
            if (other_interval != null) {
                return new Pomodoro.BooleanValue (this.data > other_interval.data);
            }

            return base.apply_gt (other);
        }
    }


    public class StringValue : Pomodoro.Value
    {
        public string data;

        public StringValue (string data)
        {
            this.data = data;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Pomodoro.StringValue);
        }

        public override string get_type_name ()
        {
            return "string";
        }

        public override bool to_boolean ()
        {
            return (this.data != null) && (this.data != "");
        }

        public override string to_representation ()
        {
            return quote_string (this.data);
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.string (this.data);
        }

        internal override Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_string = other as Pomodoro.StringValue;
            if (other_string != null) {
                return new Pomodoro.BooleanValue (this.data == other_string.data);
            }

            return other.apply_eq (this);
        }

        internal override Pomodoro.Value apply_lt (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_string = other as Pomodoro.StringValue;
            if (other_string != null) {
                return new Pomodoro.BooleanValue (this.data < other_string.data);
            }

            return other.apply_gt (this);
        }

        internal override Pomodoro.Value apply_gt (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_string = other as Pomodoro.StringValue;
            if (other_string != null) {
                return new Pomodoro.BooleanValue (this.data > other_string.data);
            }

            return other.apply_lt (this);
        }
    }


    public class StateValue : Pomodoro.Value
    {
        public Pomodoro.State data;

        public StateValue (Pomodoro.State state)
        {
            this.data = state;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Pomodoro.StateValue);
        }

        public override string get_type_name ()
        {
            return "state";
        }

        public override bool to_boolean ()
        {
            return this.data != Pomodoro.State.UNDEFINED;
        }

        public override string to_representation ()
        {
            return quote_string (this.data.to_string ());
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.string (this.data.to_string ());
        }

        public override GLib.Variant format (string name)
                                             throws Pomodoro.ExpressionError
        {
            switch (name)
            {
                case "base":
                    return new GLib.Variant.string (this.data.is_break ()
                                                    ? "break" : this.data.to_string ());

                case "full":
                    return this.to_variant ();

                default:
                    return base.format (name);
            }
        }

        internal override Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            /**
             * XXX: When serialized, we allow comparisons like `"short-break" == "break"`,
             *      which is questionable. It would be more intuitive to use functions,
             *      for this example `isBreak("short-break")`.
             */

            var other_state = other as Pomodoro.StateValue;
            if (other_state != null) {
                return new Pomodoro.BooleanValue (this.data.compare (other_state.data));
            }

            var other_string = other as Pomodoro.StringValue;
            if (other_string != null) {
                var other_data = Pomodoro.State.from_string (other_string.data);

                if (other_data == Pomodoro.State.UNDEFINED && other_string.data != "undefined") {  // TODO: rename "undefined" to "stopped"
                    return new Pomodoro.BooleanValue (false);
                }

                return new Pomodoro.BooleanValue (this.data.compare (other_data));
            }

            return base.apply_eq (other);
        }
    }


    public class StatusValue : Pomodoro.Value
    {
        public Pomodoro.TimeBlockStatus data;

        public StatusValue (Pomodoro.TimeBlockStatus status)
        {
            this.data = status;
        }

        public override GLib.Type get_value_type ()
        {
            return typeof (Pomodoro.StatusValue);
        }

        public override string get_type_name ()
        {
            return "status";
        }

        public override bool to_boolean ()
        {
            return this.data != Pomodoro.TimeBlockStatus.SCHEDULED;
        }

        public override string to_representation ()
        {
            return quote_string (this.data.to_string());
        }

        public override GLib.Variant to_variant ()
        {
            return new GLib.Variant.string (this.data.to_string ());
        }

        internal override Pomodoro.Value apply_eq (Pomodoro.Value other)
                                                   throws Pomodoro.ExpressionError
        {
            var other_status = other as Pomodoro.StatusValue;
            if (other_status != null) {
                return new Pomodoro.BooleanValue (this.data == other_status.data);
            }

            var other_string = other as Pomodoro.StringValue;
            if (other_string != null) {
                return new Pomodoro.BooleanValue (this.data.to_string () == other_string.data);
            }

            return base.apply_eq (other);
        }
    }


    public string[] list_value_formats (GLib.Type value_type)
    {
        switch (value_type.name ())
        {
            case "PomodoroTimestampValue":
                return { "iso8601", "seconds", "microseconds" };

            case "PomodoroIntervalValue":
                return { "minutes", "seconds", "microseconds" };

            case "PomodoroStateValue":
                return { "base", "full" };

            default:
                return {};
        }
    }


    public string get_default_value_format (GLib.Type value_type)
    {
        switch (value_type.name ())
        {
            case "PomodoroTimestampValue":
                return "microseconds";

            case "PomodoroIntervalValue":
                return "microseconds";

            case "PomodoroStateValue":
                return "full";

            default:
                return "";
        }
    }


    private bool get_inner_operator (Pomodoro.Expression   expression,
                                     out Pomodoro.Operator inner_operator)
    {
        if (expression is Pomodoro.Operation)
        {
            inner_operator = ((Pomodoro.Operation) expression).operator;

            return true;
        }

        if (expression is Pomodoro.Comparison)
        {
            inner_operator = ((Pomodoro.Comparison) expression).operator;

            return true;
        }

        inner_operator = Pomodoro.Operator.INVALID;

        return false;
    }


    /**
     * Wrap argument with parentheses if inner operator has higher priority
     */
    private inline string wrap_argument (string            argument_string,
                                         Pomodoro.Operator inner_operator,
                                         Pomodoro.Operator outer_operator)
    {
        return inner_operator != outer_operator &&
               inner_operator.get_precedence () < outer_operator.get_precedence ()
            ? @"($argument_string)"
            : argument_string;
    }


    public abstract class Expression
    {
        public abstract GLib.Type get_result_type ();

        public abstract Pomodoro.Value evaluate (Pomodoro.Context context)
                                                 throws Pomodoro.ExpressionError;

        public abstract string to_string ();

        public static Pomodoro.Expression? parse (string text)
                                                  throws Pomodoro.ExpressionParserError
        {
            var parser = new Pomodoro.ExpressionParser ();

            return parser.parse (text);
        }
    }


    public class Constant : Pomodoro.Expression
    {
        public Pomodoro.Value value;

        public Constant (Pomodoro.Value value)
        {
            this.value = value;
        }

        public override GLib.Type get_result_type ()
        {
            return this.value.get_value_type ();
        }

        public override Pomodoro.Value evaluate (Pomodoro.Context context)
                                                 throws Pomodoro.ExpressionError
        {
            return this.value;
        }

        public override string to_string ()
        {
            return this.value.to_representation ();
        }

        public inline string get_string ()
        {
            var string_value = this.value as Pomodoro.StringValue;

            return string_value != null ? string_value.data : "";
        }
    }


    public class Variable : Pomodoro.Expression
    {
        public string name;

        public Variable (string name)
        {
            this.name = name;
        }

        public override GLib.Type get_result_type ()
        {
            var variable_spec = Pomodoro.find_variable (this.name);

            return variable_spec?.value_type;
        }

        public override Pomodoro.Value evaluate (Pomodoro.Context context)
                                                 throws Pomodoro.ExpressionError
        {
            var value = context.evaluate_variable (this.name);

            if (value == null) {
                throw new Pomodoro.ExpressionError.INVALID (_("Unknown variable \"%s\""),
                                                            this.name);
            }

            return value;
        }

        public override string to_string ()
        {
            return Pomodoro.to_camel_case (this.name);
        }
    }


    public class Operation : Pomodoro.Expression
    {
        public Pomodoro.Operator     operator;
        public Pomodoro.Expression[] arguments;

        public Operation (Pomodoro.Operator operator, ...)
        {
            var arguments_list = va_list ();
            var arguments = new Pomodoro.Expression[0];

            while (true)
            {
                Pomodoro.Expression? argument = arguments_list.arg();

                if (argument != null) {
                    arguments += argument;
                }
                else {
                    break;
                }
            }

            this.operator  = operator;
            this.arguments = arguments;
        }

        public Operation.with_argv (Pomodoro.Operator           operator,
                                    owned Pomodoro.Expression[] arguments)
        {
            this.operator  = operator;
            this.arguments = arguments;
        }

        public override GLib.Type get_result_type ()
        {
            GLib.Type? result_type = null;

            foreach (var expression in this.arguments)
            {
                if (result_type == null) {
                    result_type = expression.get_result_type ();
                }
                else {
                    result_type = this.operator.get_result_type (result_type,
                                                                 expression.get_result_type ());
                }
            }

            return result_type;
        }

        public override Pomodoro.Value evaluate (Pomodoro.Context context)
                                                 throws Pomodoro.ExpressionError
        {
            if (this.arguments.length == 0) {
                throw new Pomodoro.ExpressionError.EMPTY ("No arguments to perform '%s' operation",
                                                          this.operator.to_string ());
            }

            Pomodoro.Value? result = null;

            foreach (var expression in this.arguments)
            {
                var expression_result = expression.evaluate (context);

                if (result == null) {
                    result = expression_result;
                }
                else {
                    result = this.operator.apply (result, expression_result);
                }
            }

            return result;
        }

        private string argument_to_string (Pomodoro.Expression expression)
        {
            var expression_string = expression.to_string ();
            Pomodoro.Operator expression_operator;

            return get_inner_operator (expression, out expression_operator)
                ? wrap_argument (expression_string, expression_operator, this.operator)
                : expression_string;
        }

        public override string to_string ()
        {
            if (this.arguments.length != 1)
            {
                var string_builder = new GLib.StringBuilder ();
                var operator_string = @" $(this.operator.to_string()) ";

                for (var index = 0; index < this.arguments.length; index++)
                {
                    if (index > 0) {
                        string_builder.append (operator_string);
                    }

                    string_builder.append (argument_to_string (this.arguments[index]));
                }

                return string_builder.str;
            }
            else {
                return this.arguments[0].to_string ();
            }
        }
    }


    public class Comparison : Pomodoro.Expression
    {
        public Pomodoro.Expression  argument_lhs;
        public Pomodoro.Expression? argument_rhs;
        public Pomodoro.Operator    operator;

        public Comparison (Pomodoro.Expression  argument_lhs,
                           Pomodoro.Operator    operator,
                           Pomodoro.Expression? argument_rhs)
        {
            this.argument_lhs = argument_lhs;
            this.operator     = operator;
            this.argument_rhs = argument_rhs;
        }

        public Comparison.is_true (Pomodoro.Expression expression)
        {
            this.argument_lhs = expression;
            this.operator     = Pomodoro.Operator.EQ;
            this.argument_rhs = new Pomodoro.Constant (new Pomodoro.BooleanValue (true));
        }

        public override GLib.Type get_result_type ()
        {
            return typeof (Pomodoro.BooleanValue);
        }

        public override Pomodoro.Value evaluate (Pomodoro.Context context)
                                                 throws Pomodoro.ExpressionError
        {
            if (this.operator.get_category () != Pomodoro.OperatorCategory.COMPARISON) {
                throw new Pomodoro.ExpressionError.INVALID ("Expecting comparison operator, not %s",
                                                            this.operator.to_string ());
            }

            if (this.argument_lhs == null || this.argument_rhs == null) {
                throw new Pomodoro.ExpressionError.EMPTY ("Missing an argument for a comparison");
            }

            var result_lhs = this.argument_lhs.evaluate (context);
            var result_rhs = this.argument_rhs.evaluate (context);

            return operator.apply (result_lhs, result_rhs);
        }

        private string argument_to_string (Pomodoro.Expression expression)
        {
            var expression_string = expression.to_string ();

            return get_inner_operator (expression, null)
                ? @"($expression_string)"
                : expression_string;
        }

        private bool argument_is_true (Pomodoro.Expression expression)
        {
            var constant = expression as Pomodoro.Constant;

            if (this.operator != Pomodoro.Operator.EQ || constant == null) {
                return false;
            }

            return constant != null &&
                   (constant.value is Pomodoro.BooleanValue) &&
                   ((Pomodoro.BooleanValue) constant.value).data;
        }

        public override string to_string ()
        {
            if (this.argument_is_true (this.argument_rhs)) {
                return this.argument_lhs.to_string ();
            }

            if (this.argument_is_true (this.argument_lhs)) {
                return this.argument_rhs.to_string ();
            }

            var argument_lhs_string = this.argument_to_string (this.argument_lhs);
            var argument_rhs_string = this.argument_to_string (this.argument_rhs);
            var operator_string     = this.operator.to_string ();

            return @"$argument_lhs_string $operator_string $argument_rhs_string";
        }
    }
}
