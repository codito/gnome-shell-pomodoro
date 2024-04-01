namespace Tests
{
    public inline void assert_value_equals (Pomodoro.Value value,
                                            Pomodoro.Value expected_value)
    {
        assert_cmpstr (value.get_type_name (),
                       GLib.CompareOperator.EQ,
                       expected_value.get_type_name ());

        assert_cmpvariant (value.to_variant (),
                           expected_value.to_variant ());
    }


    public class ConstantTest : Tests.TestSuite
    {
        private Pomodoro.Context? context;

        public ConstantTest ()
        {
            this.add_test ("state", this.test_state);
            this.add_test ("timestamp", this.test_timestamp);
            this.add_test ("interval", this.test_interval);
            this.add_test ("boolean", this.test_boolean);
        }

        public override void setup ()
        {
            this.context = new Pomodoro.Context ();
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_state ()
        {
            var state = Pomodoro.State.BREAK;
            var constant = new Pomodoro.Constant (new Pomodoro.StateValue (state));

            try {
                assert_value_equals (constant.evaluate (this.context),
                                     new Pomodoro.StateValue (state));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           @"\"$(state.to_string())\"");
        }

        public void test_timestamp ()
        {
            var timestamp = Pomodoro.Timestamp.from_now ();
            var constant = new Pomodoro.Constant (new Pomodoro.TimestampValue (timestamp));

            try {
                assert_value_equals (constant.evaluate (this.context),
                                     new Pomodoro.TimestampValue (timestamp));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           @"\"$(Pomodoro.Timestamp.to_iso8601(timestamp))\"");
        }

        public void test_interval ()
        {
            var interval = Pomodoro.Interval.HOUR;
            var constant = new Pomodoro.Constant (new Pomodoro.IntervalValue (interval));

            try {
                assert_value_equals (
                    constant.evaluate (this.context),
                    new Pomodoro.IntervalValue (interval)
                );
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           interval.to_string ());
        }

        public void test_boolean ()
        {
            var constant = new Pomodoro.Constant (new Pomodoro.BooleanValue (true));

            try {
                assert_value_equals (constant.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }

            assert_cmpstr (constant.to_string (),
                           GLib.CompareOperator.EQ,
                           "true");
        }
    }


    public class VariableTest : Tests.TestSuite
    {
        private Pomodoro.Context? context;

        public VariableTest ()
        {
            this.add_test ("timestamp", this.test_timestamp);
            this.add_test ("state", this.test_state);
            this.add_test ("status", this.test_status);
            this.add_test ("is_started", this.test_is_started);
            this.add_test ("is_paused", this.test_is_paused);
            this.add_test ("is_finished", this.test_is_finished);
            this.add_test ("is_running", this.test_is_running);
            this.add_test ("duration", this.test_duration);
            this.add_test ("offset", this.test_offset);
            this.add_test ("elapsed", this.test_elapsed);
            this.add_test ("remaining", this.test_remaining);

            this.add_test ("to_string", this.test_to_string);
        }

        public override void setup ()
        {
            var time_block = new Pomodoro.TimeBlock (Pomodoro.State.SHORT_BREAK);
            time_block.set_time_range (1000, 1600);
            time_block.set_status (Pomodoro.TimeBlockStatus.COMPLETED);

            var context = new Pomodoro.Context ();
            context.timestamp = 1000;
            context.timer_state = Pomodoro.TimerState () {
                duration = 600,
                user_data = time_block
            };
            context.time_block = time_block;

            this.context = context;
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_timestamp ()
        {
            var variable = new Pomodoro.Variable ("timestamp");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.TimestampValue (1000));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_state ()
        {
            var variable = new Pomodoro.Variable ("state");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.StateValue (Pomodoro.State.SHORT_BREAK));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_status ()
        {
            var variable = new Pomodoro.Variable ("status");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.StatusValue (Pomodoro.TimeBlockStatus.COMPLETED));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_started ()
        {
            var variable = new Pomodoro.Variable ("is-started");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_paused ()
        {
            var variable = new Pomodoro.Variable ("is-paused");

            try {
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                this.context.timer_state.paused_time = 1400;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_finished ()
        {
            var variable = new Pomodoro.Variable ("is-finished");

            try {
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                this.context.timer_state.finished_time = 1600;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_is_running ()
        {
            var variable = new Pomodoro.Variable ("is-running");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));

                this.context.timer_state.paused_time = 1400;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                this.context.timer_state.paused_time = Pomodoro.Timestamp.UNDEFINED;
                this.context.timer_state.finished_time = 1600;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_duration ()
        {
            var variable = new Pomodoro.Variable ("duration");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.IntervalValue (600));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_offset ()
        {
            var variable = new Pomodoro.Variable ("offset");

            try {
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.IntervalValue (0));

                this.context.timer_state.offset = 60;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.IntervalValue (60));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_elapsed ()
        {
            var variable = new Pomodoro.Variable ("elapsed");

            try {
                this.context.timestamp = 1300;
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.IntervalValue (100));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_remaining ()
        {
            var variable = new Pomodoro.Variable ("remaining");

            try {
                this.context.timestamp = 1300;
                this.context.timer_state.started_time = 1200;
                assert_value_equals (variable.evaluate (this.context),
                                     new Pomodoro.IntervalValue (500));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_to_string ()
        {
            var variable = new Pomodoro.Variable ("is-paused");

            assert_cmpstr (variable.to_string (),
                           GLib.CompareOperator.EQ,
                           "isPaused");
        }
    }


    public class OperationTest : Tests.TestSuite
    {
        private Pomodoro.Context? context;

        public OperationTest ()
        {
            this.add_test ("and__boolean", this.test_and__boolean);
            this.add_test ("and__timestamp", this.test_and__timestamp);
            this.add_test ("and__state", this.test_and__state);

            this.add_test ("to_string__single_argument", this.test_to_string__single_argument);
            this.add_test ("to_string__nested", this.test_to_string__nested);
            this.add_test ("to_string__wrap_argument", this.test_to_string__wrap_argument);
        }

        public override void setup ()
        {
            this.context = new Pomodoro.Context ();
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_and__boolean ()
        {
            bool[,] cases = {
                { false, false, false },
                { false, true, false },
                { true, false, false },
                { true, true, true }
            };

            for (var index=0; index < 4; index++)
            {
                var value_1 = new Pomodoro.BooleanValue (cases[index, 0]);
                var value_2 = new Pomodoro.BooleanValue (cases[index, 1]);
                var expected_result = new Pomodoro.BooleanValue (cases[index, 2]);

                var operation = new Pomodoro.Operation (Pomodoro.Operator.AND,
                                                        new Pomodoro.Constant (value_1),
                                                        new Pomodoro.Constant (value_2));
                try {
                    assert_value_equals (operation.evaluate (this.context),
                                         expected_result);
                }
                catch (Pomodoro.ExpressionError error) {
                    assert_no_error (error);
                }
            }
        }

        public void test_and__timestamp ()
        {
            var value_1 = new Pomodoro.TimestampValue (Pomodoro.Timestamp.UNDEFINED);
            var value_2 = new Pomodoro.TimestampValue (Pomodoro.Timestamp.from_now ());
            var value_3 = new Pomodoro.BooleanValue (true);

            try {
                var operation_1 = new Pomodoro.Operation (Pomodoro.Operator.AND,
                                                          new Pomodoro.Constant (value_1),
                                                          new Pomodoro.Constant (value_3));
                assert_value_equals (operation_1.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                var operation_2 = new Pomodoro.Operation (Pomodoro.Operator.AND,
                                                          new Pomodoro.Constant (value_2),
                                                          new Pomodoro.Constant (value_3));
                assert_value_equals (operation_2.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_and__state ()
        {
            var value_1 = new Pomodoro.StateValue (Pomodoro.State.UNDEFINED);
            var value_2 = new Pomodoro.StateValue (Pomodoro.State.POMODORO);
            var value_3 = new Pomodoro.BooleanValue (true);

            try {
                var operation_1 = new Pomodoro.Operation (Pomodoro.Operator.AND,
                                                          new Pomodoro.Constant (value_1),
                                                          new Pomodoro.Constant (value_3));
                assert_value_equals (operation_1.evaluate (this.context),
                                     new Pomodoro.BooleanValue (false));

                var operation_2 = new Pomodoro.Operation (Pomodoro.Operator.AND,
                                                          new Pomodoro.Constant (value_2),
                                                          new Pomodoro.Constant (value_3));
                assert_value_equals (operation_2.evaluate (this.context),
                                     new Pomodoro.BooleanValue (true));
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_to_string__single_argument ()
        {
            var argument_1 = new Pomodoro.Variable ("is-paused");
            var argument_2 = new Pomodoro.Constant (
                new Pomodoro.IntervalValue (Pomodoro.Interval.HOUR));
            var argument_3 = new Pomodoro.Comparison (
                new Pomodoro.Variable ("state"),
                Pomodoro.Operator.EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO)));
            var argument_4 = new Pomodoro.Operation (Pomodoro.Operator.OR, argument_1, argument_3);

            var operation_1 = new Pomodoro.Operation (Pomodoro.Operator.AND, argument_1);
            assert_cmpstr (operation_1.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_1.to_string ());

            var operation_2 = new Pomodoro.Operation (Pomodoro.Operator.AND, argument_2);
            assert_cmpstr (operation_2.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_2.to_string ());

            var operation_3 = new Pomodoro.Operation (Pomodoro.Operator.AND, argument_3);
            assert_cmpstr (operation_3.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_3.to_string ());

            var operation_4 = new Pomodoro.Operation (Pomodoro.Operator.AND, argument_4);
            assert_cmpstr (operation_4.to_string (),
                           GLib.CompareOperator.EQ,
                           argument_4.to_string ());
        }

        public void test_to_string__nested ()
        {
            var argument_1 = new Pomodoro.Variable ("is-started");
            var argument_2 = new Pomodoro.Variable ("is-paused");
            var argument_3 = new Pomodoro.Variable ("is-running");
            var argument_4 = new Pomodoro.Variable ("is-finished");

            var operation_1 = new Pomodoro.Operation (
                Pomodoro.Operator.AND,
                new Pomodoro.Operation (Pomodoro.Operator.OR, argument_1, argument_2),
                new Pomodoro.Operation (Pomodoro.Operator.OR, argument_3, argument_4)
            );
            assert_cmpstr (operation_1.to_string (),
                           GLib.CompareOperator.EQ,
                           "(isStarted || isPaused) && (isRunning || isFinished)");

            var operation_2 = new Pomodoro.Operation (
                Pomodoro.Operator.OR,
                new Pomodoro.Operation (Pomodoro.Operator.AND, argument_1, argument_2),
                new Pomodoro.Operation (Pomodoro.Operator.AND, argument_3, argument_4)
            );
            assert_cmpstr (operation_2.to_string (),
                           GLib.CompareOperator.EQ,
                           "isStarted && isPaused || isRunning && isFinished");
        }

        public void test_to_string__wrap_argument ()
        {
            var argument_1 = new Pomodoro.Variable ("state");
            var argument_2 = new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO));
            var argument_3 = new Pomodoro.Variable ("is-started");
            var argument_4 = new Pomodoro.Variable ("is-paused");

            var operation = new Pomodoro.Operation (
                Pomodoro.Operator.AND,
                new Pomodoro.Comparison (argument_1, Pomodoro.Operator.EQ, argument_2),
                new Pomodoro.Operation (Pomodoro.Operator.OR, argument_3, argument_4)
            );
            assert_cmpstr (operation.to_string (),
                           GLib.CompareOperator.EQ,
                           "state == \"pomodoro\" && (isStarted || isPaused)");
        }

        // TODO
    }


    public class ComparisonTest : Tests.TestSuite
    {
        private Pomodoro.Context? context;

        public ComparisonTest ()
        {
            this.add_test ("eq__state", this.test_eq__state);
            this.add_test ("not_eq__state", this.test_not_eq__state);

            this.add_test ("to_string__simple", this.test_to_string__simple);
            this.add_test ("to_string__nested", this.test_to_string__nested);
            this.add_test ("to_string__is_true", this.test_to_string__is_true);
        }

        public override void setup ()
        {
            this.context = new Pomodoro.Context ();
        }

        public override void teardown ()
        {
            this.context = null;
        }

        public void test_eq__state ()
        {
            var comparison_1 = new Pomodoro.Comparison (
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO)),
                Pomodoro.Operator.EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO)));

            try {
                assert_true (comparison_1.evaluate (this.context)?.to_boolean ());
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }

            var comparison_2 = new Pomodoro.Comparison (
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.SHORT_BREAK)),
                Pomodoro.Operator.EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.BREAK)));

            try {
                assert_true (comparison_2.evaluate (this.context)?.to_boolean ());
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_not_eq__state ()
        {
            var comparison = new Pomodoro.Comparison (
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.UNDEFINED)),
                Pomodoro.Operator.NOT_EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO)));

            try {
                assert_true (comparison.evaluate (this.context)?.to_boolean ());
            }
            catch (Pomodoro.ExpressionError error) {
                assert_no_error (error);
            }
        }

        public void test_to_string__simple ()
        {
            var comparison = new Pomodoro.Comparison (
                new Pomodoro.Variable ("state"),
                Pomodoro.Operator.EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO)));
            assert_cmpstr (comparison.to_string (),
                           GLib.CompareOperator.EQ,
                           "state == \"pomodoro\"");
        }

        public void test_to_string__nested ()
        {
            var comparison_1 = new Pomodoro.Comparison (
                new Pomodoro.Variable ("state"),
                Pomodoro.Operator.EQ,
                new Pomodoro.Constant (new Pomodoro.StateValue (Pomodoro.State.POMODORO)));
            var comparison_2 = new Pomodoro.Comparison (
                new Pomodoro.Variable ("duration"),
                Pomodoro.Operator.GT,
                new Pomodoro.Constant (new Pomodoro.IntervalValue (Pomodoro.Interval.MINUTE)));

            var comparison = new Pomodoro.Comparison (comparison_1,
                                                      Pomodoro.Operator.EQ,
                                                      comparison_2);
            assert_cmpstr (comparison.to_string (),
                           GLib.CompareOperator.EQ,
                           "(state == \"pomodoro\") == (duration > 60000000)");
        }

        public void test_to_string__is_true ()
        {
            var comparison = new Pomodoro.Comparison.is_true (new Pomodoro.Variable ("is-started"));
            assert_cmpstr (comparison.to_string (),
                           GLib.CompareOperator.EQ,
                           "isStarted");
        }

        // TODO
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.ConstantTest (),
        new Tests.VariableTest (),
        new Tests.OperationTest (),
        new Tests.ComparisonTest ()
    );
    // TODO: test available value formats
}
