namespace Tests
{
    private inline void assert_value_equals (Pomodoro.Value? value,
                                             Pomodoro.Value  expected_value)
    {
        assert_nonnull (value);

        assert_cmpstr (
                value.get_type_name (),
                GLib.CompareOperator.EQ,
                expected_value.get_type_name ());

        assert_cmpvariant (
                value.to_variant (),
                expected_value.to_variant ());
    }


    private inline void assert_root_has_operator (Pomodoro.Expression expression,
                                                  Pomodoro.Operator   operator)
    {
        if (expression is Pomodoro.Operation)
        {
            var operation = (Pomodoro.Operation) expression;
            assert_cmpstr (operation.operator.to_string (),
                           GLib.CompareOperator.EQ,
                           operator.to_string ());
            return;
        }

        if (expression is Pomodoro.Comparison)
        {
            var comparison = (Pomodoro.Comparison) expression;
            assert_cmpstr (comparison.operator.to_string (),
                           GLib.CompareOperator.EQ,
                           operator.to_string ());
            return;
        }

        assert_not_reached ();
    }


    public class ExpressionParserTest : Tests.TestSuite
    {
        private GLib.Quark error_domain;

        public ExpressionParserTest ()
        {
            this.add_test ("parse_empty", this.test_parse_empty);

            this.add_test ("parse_string_literal__string", this.test_parse_string_literal__string);
            this.add_test ("parse_string_literal__state", this.test_parse_string_literal__state);
            this.add_test ("parse_string_literal__status", this.test_parse_string_literal__status);
            this.add_test ("parse_string_literal__timestamp", this.test_parse_string_literal__timestamp);
            this.add_test ("parse_string_literal__syntax_error", this.test_parse_string_literal__syntax_error);

            this.add_test ("parse_numeric_literal__interval", this.test_parse_numeric_literal__interval);
            this.add_test ("parse_numeric_literal__syntax_error", this.test_parse_numeric_literal__syntax_error);

            this.add_test ("parse_identifier__variable", this.test_parse_identifier__variable);
            this.add_test ("parse_identifier__boolean", this.test_parse_identifier__boolean);
            this.add_test ("parse_identifier__syntax_error", this.test_parse_identifier__syntax_error);
            this.add_test ("parse_identifier__unknown_identifier_error", this.test_parse_identifier__unknown_identifier_error);

            this.add_test ("parse_operator__or", this.test_parse_operator__or);
            this.add_test ("parse_operator__and", this.test_parse_operator__and);
            this.add_test ("parse_operator__eq", this.test_parse_operator__eq);
            this.add_test ("parse_operator__gt", this.test_parse_operator__gt);

            this.add_test ("parse_parentheses", this.test_parse_parentheses);
            this.add_test ("parse_parentheses__syntax_error", this.test_parse_parentheses__syntax_error);

            this.add_test ("precedence__logical_operator", this.test_precedence__logical_operator);
            this.add_test ("precedence__comparison_operator", this.test_precedence__comparison_operator);

            this.add_test ("syntax_error", this.test_syntax_error);
        }

        public override void setup ()
        {
            this.error_domain = GLib.Quark.from_string ("pomodoro-expression-parser-error-quark");
        }

        public void test_parse_empty ()
        {
            try {
                assert_null (Pomodoro.Expression.parse (""));
                assert_null (Pomodoro.Expression.parse (" "));
                assert_null (Pomodoro.Expression.parse ("\n"));
                assert_null (Pomodoro.Expression.parse ("\t"));
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        /*
         * String Literal
         */

        public void test_parse_string_literal__string ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("\"hello\"");
                var expression_2 = Pomodoro.Expression.parse (" \"hello\" ");
                var expression_3 = Pomodoro.Expression.parse ("\"a\nb\"");
                var expression_4 = Pomodoro.Expression.parse (""" "a\"b" """);

                assert_cmpstr ((expression_1 as Pomodoro.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "hello");
                assert_cmpstr ((expression_2 as Pomodoro.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "hello");
                assert_cmpstr ((expression_3 as Pomodoro.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "a\nb");
                assert_cmpstr ((expression_4 as Pomodoro.Constant)?.get_string (),
                               GLib.CompareOperator.EQ,
                               "a\"b");
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__state ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("\"pomodoro\"") as Pomodoro.Constant;
                assert_value_equals (expression_1?.value,
                                     new Pomodoro.StateValue (Pomodoro.State.POMODORO));

                var expression_2 = Pomodoro.Expression.parse ("\"break\"") as Pomodoro.Constant;
                assert_value_equals (expression_2?.value,
                                     new Pomodoro.StateValue (Pomodoro.State.BREAK));

                var expression_3 = Pomodoro.Expression.parse ("\"short-break\"") as Pomodoro.Constant;
                assert_value_equals (expression_3?.value,
                                     new Pomodoro.StateValue (Pomodoro.State.SHORT_BREAK));

                var expression_4 = Pomodoro.Expression.parse ("\"long-break\"") as Pomodoro.Constant;
                assert_value_equals (expression_4?.value,
                                     new Pomodoro.StateValue (Pomodoro.State.LONG_BREAK));

                var expression_5 = Pomodoro.Expression.parse ("\"stopped\"") as Pomodoro.Constant;
                assert_value_equals (expression_5?.value,
                                     new Pomodoro.StateValue (Pomodoro.State.STOPPED));
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__status ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("\"scheduled\"") as Pomodoro.Constant;
                assert_value_equals (expression_1?.value,
                                     new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.SCHEDULED));

                var expression_2 = Pomodoro.Expression.parse ("\"in-progress\"") as Pomodoro.Constant;
                assert_value_equals (expression_2?.value,
                                     new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.IN_PROGRESS));

                var expression_3 = Pomodoro.Expression.parse ("\"completed\"") as Pomodoro.Constant;
                assert_value_equals (expression_3?.value,
                                     new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.COMPLETED));

                var expression_4 = Pomodoro.Expression.parse ("\"uncompleted\"") as Pomodoro.Constant;
                assert_value_equals (expression_4?.value,
                                     new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.UNCOMPLETED));
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__timestamp ()
        {
            try {
                var expected_timestamp = Pomodoro.Timestamp.from_seconds_uint (1014304205);

                var expression = Pomodoro.Expression.parse ("\"2002-02-21T15:10:05Z\"") as Pomodoro.Constant;
                assert_value_equals (expression?.value,
                                     new Pomodoro.TimestampValue (expected_timestamp));
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_string_literal__syntax_error ()
        {
            string[] invalid_texts = {
                "\"hello",
                " \"hello\" \"world\" ",
                "'hello'"
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Pomodoro.Expression.parse (text);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    assert_error (error,
                                  this.error_domain,
                                  Pomodoro.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }

        /*
         * Numeric Literal / Intervals
         */

        public void test_parse_numeric_literal__interval ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("1") as Pomodoro.Constant;
                assert_value_equals (expression_1?.value,
                                     new Pomodoro.IntervalValue (Pomodoro.Interval.MICROSECOND));

                var expression_2 = Pomodoro.Expression.parse ("0") as Pomodoro.Constant;
                assert_value_equals (expression_2?.value,
                                     new Pomodoro.IntervalValue (0));

                var expression_3 = Pomodoro.Expression.parse ("1000000") as Pomodoro.Constant;
                assert_value_equals (expression_3?.value,
                                     new Pomodoro.IntervalValue (Pomodoro.Interval.SECOND));

                var expression_4 = Pomodoro.Expression.parse ("-1000000") as Pomodoro.Constant;
                assert_value_equals (expression_4?.value,
                                     new Pomodoro.IntervalValue (-Pomodoro.Interval.SECOND));
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_numeric_literal__syntax_error ()
        {
            string[] invalid_texts = {
                "-",
                "123D"
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Pomodoro.Expression.parse (text);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    assert_error (error,
                                  this.error_domain,
                                  Pomodoro.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }

        /*
         * Identifier
         */

        public void test_parse_identifier__variable ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("isPaused");
                assert_true (expression_1 is Pomodoro.Variable);
                assert_cmpstr ((expression_1 as Pomodoro.Variable)?.name,
                                GLib.CompareOperator.EQ,
                                "is-paused");

                var expression_2 = Pomodoro.Expression.parse (" isPaused ");
                assert_true (expression_2 is Pomodoro.Variable);
                assert_cmpstr ((expression_2 as Pomodoro.Variable)?.name,
                                GLib.CompareOperator.EQ,
                                "is-paused");
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_identifier__boolean ()
        {
            try {
                var true_constant = Pomodoro.Expression.parse ("true") as Pomodoro.Constant;
                assert_nonnull (true_constant);
                assert_true (true_constant.value is Pomodoro.BooleanValue);

                var true_value = (Pomodoro.BooleanValue) true_constant.value;
                assert_true (true_value.data);
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }

            try {
                var false_constant = Pomodoro.Expression.parse ("false") as Pomodoro.Constant;
                assert_nonnull (false_constant);
                assert_true (false_constant.value is Pomodoro.BooleanValue);

                var false_value = (Pomodoro.BooleanValue) false_constant.value;
                assert_false (false_value.data);
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_identifier__syntax_error ()
        {
            string[] invalid_texts = {
                "isPaused isPaused",
                "123abc",
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Pomodoro.Expression.parse (text);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    assert_error (error, this.error_domain, Pomodoro.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }

        public void test_parse_identifier__unknown_identifier_error ()
        {
            string[] unknown_names = {
                "abc123",
                "Foo",
                "TRUE",
                "True",
                "FALSE",
                "False",
                "null",
                "undefined",
                "NaN",
            };

            foreach (var name in unknown_names)
            {
                try {
                    Pomodoro.Expression.parse (name);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    assert_error (error, this.error_domain, Pomodoro.ExpressionParserError.UNKNOWN_IDENTIFIER);
                }
            }
        }

        /*
         * Operators
         */

        public void test_parse_operator__or ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse (
                    "isPaused || isFinished") as Pomodoro.Operation;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Pomodoro.Operator.OR);
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused || isFinished");

                var expression_2 = Pomodoro.Expression.parse (
                    "isPaused||isFinished||isStarted") as Pomodoro.Operation;
                assert_nonnull (expression_2);
                assert_true (expression_2.operator == Pomodoro.Operator.OR);
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused || isFinished || isStarted");
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_operator__and ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse (
                    "isPaused && isFinished") as Pomodoro.Operation;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Pomodoro.Operator.AND);
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused && isFinished");

                var expression_2 = Pomodoro.Expression.parse (
                    "isPaused&&isFinished&&isStarted") as Pomodoro.Operation;
                assert_nonnull (expression_2);
                assert_true (expression_2.operator == Pomodoro.Operator.AND);
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused && isFinished && isStarted");
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_operator__eq ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse (
                    "isPaused == isFinished") as Pomodoro.Comparison;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Pomodoro.Operator.EQ);
                var expression_1_lhs = expression_1.argument_lhs as Pomodoro.Variable;
                assert_cmpstr (expression_1_lhs.name,
                               GLib.CompareOperator.EQ,
                               "is-paused");
                var expression_1_rhs = expression_1.argument_rhs as Pomodoro.Variable;
                assert_cmpstr (expression_1_rhs.name,
                               GLib.CompareOperator.EQ,
                               "is-finished");

                // TODO: make a chain of comparisons using AND operator
                // var expression_2 = Pomodoro.Expression.parse (
                //     "isPaused == isFinished == isRunning") as Pomodoro.Operation;
                // assert_nonnull (expression_1);
                // assert_true (expression_1.operator == Pomodoro.Operator.AND);
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_operator__gt ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse (
                    "isPaused > isFinished") as Pomodoro.Comparison;
                assert_nonnull (expression_1);
                assert_true (expression_1.operator == Pomodoro.Operator.GT);
                var expression_1_lhs = expression_1.argument_lhs as Pomodoro.Variable;
                assert_cmpstr (expression_1_lhs.name,
                               GLib.CompareOperator.EQ,
                               "is-paused");
                var expression_1_rhs = expression_1.argument_rhs as Pomodoro.Variable;
                assert_cmpstr (expression_1_rhs.name,
                               GLib.CompareOperator.EQ,
                               "is-finished");
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }


        /*
         * Parentheses
         */

        public void test_parse_parentheses ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("(isPaused)") as Pomodoro.Variable;
                assert_nonnull (expression_1);
                assert_cmpstr (expression_1.name,
                               GLib.CompareOperator.EQ,
                               "is-paused");
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused");

                var expression_2 = Pomodoro.Expression.parse ("((isPaused))") as Pomodoro.Variable;
                assert_nonnull (expression_2);
                assert_cmpstr (expression_2.name,
                                GLib.CompareOperator.EQ,
                                "is-paused");
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused");

                var expression_3 = Pomodoro.Expression.parse (
                    "(isPaused && isStarted)") as Pomodoro.Operation;
                assert_nonnull (expression_3);
                assert_true (expression_3.operator == Pomodoro.Operator.AND);
                assert_cmpstr (expression_3.to_string (),
                               GLib.CompareOperator.EQ,
                               "isPaused && isStarted");

                var expression_4 = Pomodoro.Expression.parse (
                    "(isPaused || isStarted) && isFinished") as Pomodoro.Operation;
                assert_nonnull (expression_4);
                assert_true (expression_4.operator == Pomodoro.Operator.AND);
                assert_cmpstr (expression_4.to_string (),
                               GLib.CompareOperator.EQ,
                               "(isPaused || isStarted) && isFinished");

                var expression_5 = Pomodoro.Expression.parse ("()");
                assert_null (expression_5);
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_parse_parentheses__syntax_error ()
        {
            string[] invalid_texts = {
                "(",
                ")",
                "())",
                "(()",
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Pomodoro.Expression.parse (text);

                    GLib.error ("No error raised for '%s'", text);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    assert_error (error,
                                  this.error_domain,
                                  Pomodoro.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }


        /*
         * Precedence
         */

        public void test_precedence__logical_operator ()
        {
            try {
                /*
                 *      ||
                 *     /  \
                 * false   &&
                 *        /  \
                 *    false   true
                 */
                var expression_1 = Pomodoro.Expression.parse ("false || false && true");
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "false || false && true");
                assert_root_has_operator (expression_1, Pomodoro.Operator.OR);

                /*
                 *         ||
                 *        /  \
                 *      &&    true
                 *     /  \
                 * false   true
                 */
                var expression_2 = Pomodoro.Expression.parse ("false && false || true");
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "false && false || true");
                assert_root_has_operator (expression_2, Pomodoro.Operator.OR);

                var expression_3 = Pomodoro.Expression.parse (
                    "false && false && false || true || true");
                assert_cmpstr (expression_3.to_string (),
                               GLib.CompareOperator.EQ,
                               "false && false && false || true || true");
                assert_root_has_operator (expression_3, Pomodoro.Operator.OR);
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }

        public void test_precedence__comparison_operator ()
        {
            try {
                var expression_1 = Pomodoro.Expression.parse ("true && false != true");
                assert_cmpstr (expression_1.to_string (),
                               GLib.CompareOperator.EQ,
                               "true && false != true");
                assert_root_has_operator (expression_1, Pomodoro.Operator.AND);

                var expression_2 = Pomodoro.Expression.parse ("true != false && true");
                assert_cmpstr (expression_2.to_string (),
                               GLib.CompareOperator.EQ,
                               "true != false && true");
                assert_root_has_operator (expression_2, Pomodoro.Operator.AND);

                var expression_3 = Pomodoro.Expression.parse ("true || false != true");
                assert_cmpstr (expression_3.to_string (),
                               GLib.CompareOperator.EQ,
                               "true || false != true");
                assert_root_has_operator (expression_3, Pomodoro.Operator.OR);
            }
            catch (Pomodoro.ExpressionParserError error) {
                assert_no_error (error);
            }
        }


        /*
         * Misc
         */

        public void test_syntax_error ()
        {
            string[] invalid_texts = {
                "/* comment */",
                "// comment",
                ";",
                "arr[0]",
                "[1, 2, 3]",
                "**",
                "(&& isStarted)",
                "^",
                "isPaused ==",
            };

            foreach (var text in invalid_texts)
            {
                try {
                    Pomodoro.Expression.parse (text);
                }
                catch (Pomodoro.ExpressionParserError error) {
                    assert_error (error, this.error_domain, Pomodoro.ExpressionParserError.SYNTAX_ERROR);
                }
            }
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.ExpressionParserTest ()
    );
}
