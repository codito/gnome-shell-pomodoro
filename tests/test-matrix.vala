namespace Tests
{
    public class MatrixTest : Tests.TestSuite
    {
        public MatrixTest ()
        {
            this.add_test ("get", this.test_get);
            this.add_test ("set", this.test_set);
            this.add_test ("resize", this.test_resize);
            this.add_test ("add", this.test_add);
            this.add_test ("min", this.test_min);
            this.add_test ("max", this.test_max);
            this.add_test ("sum", this.test_sum);
            this.add_test ("unstack", this.test_unstack);
        }

        public void test_get ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });

            assert_cmpfloat (matrix.@get (0, 0), GLib.CompareOperator.EQ, 4.0);
            assert_cmpfloat (matrix.@get (1, 1), GLib.CompareOperator.EQ, 7.0);
            assert_cmpfloat (matrix.@get (0, 1), GLib.CompareOperator.EQ, 1.0);
            assert_cmpfloat (matrix.@get (1, 0), GLib.CompareOperator.EQ, 2.0);
            assert_cmpfloat (matrix.@get (1, 2), GLib.CompareOperator.EQ, 8.0);

            assert_true (matrix.@get (2, 0).is_nan ());
            assert_true (matrix.@get (0, 3).is_nan ());
        }

        public void test_set ()
        {
            var matrix = new Pomodoro.Matrix (2, 3);

            matrix.@set (0, 0, 4.0);
            assert_cmpfloat (matrix.@get (0, 0), GLib.CompareOperator.EQ, 4.0);

            matrix.@set (1, 1, 7.0);
            assert_cmpfloat (matrix.@get (1, 1), GLib.CompareOperator.EQ, 7.0);

            matrix.@set (1, 2, 8.0);
            assert_cmpfloat (matrix.@get (1, 2), GLib.CompareOperator.EQ, 8.0);

            matrix.@set (2, 0, 100.0);
            assert_true (matrix.@get (2, 0).is_nan ());

            matrix.@set (0, 3, 100.0);
            assert_true (matrix.@get (0, 3).is_nan ());
        }

        public void test_resize ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });

            var expected_result = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0, 0.0, 0.0 },
                { 2.0, 7.0, 8.0, 0.0, 0.0 },
                { 0.0, 0.0, 0.0, 0.0, 0.0 }
            });
            matrix.resize (expected_result.shape[0], expected_result.shape[1]);
            // GLib.debug ("result = %s", matrix.to_representation ());
            assert_true (matrix.equals (expected_result));

            expected_result = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0 }
            });
            matrix.resize (1, 2);
            // GLib.debug ("result = %s", matrix.to_representation ());
            assert_true (matrix.equals (expected_result));
        }

        public void test_add ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });
            var other = new Pomodoro.Matrix.from_array ({
                { 0.0, 2.0, -3.0 },
                { 6.0, 1.0, 1.0 }
            });
            var expected_result = new Pomodoro.Matrix.from_array ({
                { 4.0, 3.0, 0.0 },
                { 8.0, 8.0, 9.0 }
            });
            assert_true (matrix.add (other));
            // GLib.debug ("result = %s", matrix.to_representation ());

            assert_true (matrix.equals (expected_result));
        }

        public void test_min ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });
            assert_cmpfloat (matrix.min (), GLib.CompareOperator.EQ, 1.0);
        }

        public void test_max ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });
            assert_cmpfloat (matrix.max (), GLib.CompareOperator.EQ, 8.0);
        }

        public void test_sum ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });
            assert_cmpfloat (matrix.sum (), GLib.CompareOperator.EQ, 25.0);
        }

        public void test_unstack ()
        {
            var matrix = new Pomodoro.Matrix.from_array ({
                { 4.0, 1.0, 3.0 },
                { 2.0, 7.0, 8.0 }
            });

            var result_0 = matrix.unstack (0);
            assert_cmpuint (result_0.length, GLib.CompareOperator.EQ, matrix.shape[0]) ;
            assert_true (result_0[0].equals (matrix.get_vector (0, 0)));
            assert_true (result_0[1].equals (matrix.get_vector (0, 1)));

            var result_1 = matrix.unstack (1);
            assert_cmpuint (result_1.length, GLib.CompareOperator.EQ, matrix.shape[1]) ;
            assert_true (result_1[0].equals (matrix.get_vector (1, 0)));
            assert_true (result_1[1].equals (matrix.get_vector (1, 1)));
            assert_true (result_1[2].equals (matrix.get_vector (1, 2)));
        }
    }


    public class Matrix3DTest : Tests.TestSuite
    {
        public Matrix3DTest ()
        {
            this.add_test ("get", this.test_get);
            this.add_test ("set", this.test_set);
            this.add_test ("resize", this.test_resize);
            this.add_test ("min", this.test_min);
            this.add_test ("max", this.test_max);
            this.add_test ("sum", this.test_sum);
            this.add_test ("unstack", this.test_unstack);
        }

        public void test_get ()
        {
            var matrix = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0 },
                    { 1.0, 0.0 },
                    { 3.0, 9.0 }
                },
                {
                    { 2.0, 3.0 },
                    { 7.0, 1.0 },
                    { 8.0, 0.0 }
                }
            });

            assert_cmpfloat (matrix.@get (0, 0, 1), GLib.CompareOperator.EQ, -1.0);
            assert_cmpfloat (matrix.@get (1, 0, 0), GLib.CompareOperator.EQ, 2.0);
            assert_cmpfloat (matrix.@get (0, 1, 0), GLib.CompareOperator.EQ, 1.0);

            assert_true (matrix.@get (2, 0, 0).is_nan ());
            assert_true (matrix.@get (0, 3, 0).is_nan ());
            assert_true (matrix.@get (0, 0, 2).is_nan ());
        }

        public void test_set ()
        {
            var matrix = new Pomodoro.Matrix3D (2, 3, 2);

            matrix.@set (0, 0, 1, 4.0);
            assert_cmpfloat (matrix.@get (0, 0, 1), GLib.CompareOperator.EQ, 4.0);

            matrix.@set (0, 1, 0, 7.0);
            assert_cmpfloat (matrix.@get (0, 1, 0), GLib.CompareOperator.EQ, 7.0);

            matrix.@set (1, 2, 1, 8.0);
            assert_cmpfloat (matrix.@get (1, 2, 1), GLib.CompareOperator.EQ, 8.0);

            matrix.@set (2, 0, 0, 100.0);
            assert_true (matrix.@get (2, 0, 0).is_nan ());

            matrix.@set (0, 3, 0, 100.0);
            assert_true (matrix.@get (0, 3, 0).is_nan ());

            matrix.@set (0, 0, 2, 100.0);
            assert_true (matrix.@get (0, 0, 2).is_nan ());
        }

        public void test_resize ()
        {
            var matrix = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0 },
                    { 1.0, 0.0 },
                    { 3.0, 9.0 }
                },
                {
                    { 2.0, 3.0 },
                    { 7.0, 1.0 },
                    { 8.0, 0.0 }
                }
            });
            var expected_result = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0, 0.0, 0.0 },
                    { 1.0, 0.0, 0.0, 0.0 },
                    { 3.0, 9.0, 0.0, 0.0 }
                },
                {
                    { 2.0, 3.0, 0.0, 0.0 },
                    { 7.0, 1.0, 0.0, 0.0 },
                    { 8.0, 0.0, 0.0, 0.0 }
                },
                {
                    { 0.0, 0.0, 0.0, 0.0 },
                    { 0.0, 0.0, 0.0, 0.0 },
                    { 0.0, 0.0, 0.0, 0.0 }
                }
            });

            matrix.resize (expected_result.shape[0],
                           expected_result.shape[1],
                           expected_result.shape[2]);
            assert_true (matrix.equals (expected_result));
        }

        public void test_min ()
        {
            var matrix = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0 },
                    { 1.0, 0.0 },
                    { 3.0, 9.0 }
                },
                {
                    { 2.0, 3.0 },
                    { 7.0, 1.0 },
                    { 8.0, 0.0 }
                }
            });
            assert_cmpfloat (matrix.min (), GLib.CompareOperator.EQ, -1.0);
        }

        public void test_max ()
        {
            var matrix = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0 },
                    { 1.0, 0.0 },
                    { 3.0, 9.0 }
                },
                {
                    { 2.0, 3.0 },
                    { 7.0, 1.0 },
                    { 8.0, 0.0 }
                }
            });
            assert_cmpfloat (matrix.max (), GLib.CompareOperator.EQ, 9.0);
        }

        public void test_sum ()
        {
            var matrix = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0 },
                    { 1.0, 0.0 },
                    { 3.0, 9.0 }
                },
                {
                    { 2.0, 3.0 },
                    { 7.0, 1.0 },
                    { 8.0, 0.0 }
                }
            });
            assert_cmpfloat (matrix.sum (), GLib.CompareOperator.EQ, 37.0);
        }

        public void test_unstack ()
        {
            var matrix = new Pomodoro.Matrix3D.from_array ({
                {
                    { 4.0, -1.0 },
                    { 1.0, 0.0 },
                    { 3.0, 9.0 }
                },
                {
                    { 2.0, 3.0 },
                    { 7.0, 1.0 },
                    { 8.0, 0.0 }
                }
            });

            var result_0 = matrix.unstack (0);
            assert_cmpuint (result_0.length, GLib.CompareOperator.EQ, matrix.shape[0]);
            assert_true (result_0[0].equals (matrix.get_matrix (0, 0)));
            assert_true (result_0[1].equals (matrix.get_matrix (0, 1)));

            var result_1 = matrix.unstack (1);
            assert_cmpuint (result_1.length, GLib.CompareOperator.EQ, matrix.shape[1]);
            assert_true (result_1[0].equals (matrix.get_matrix (1, 0)));
            assert_true (result_1[1].equals (matrix.get_matrix (1, 1)));
            assert_true (result_1[2].equals (matrix.get_matrix (1, 2)));

            var result_2 = matrix.unstack (2);
            assert_cmpuint (result_2.length, GLib.CompareOperator.EQ, matrix.shape[2]);
            assert_true (result_2[0].equals (matrix.get_matrix (2, 0)));
            assert_true (result_2[1].equals (matrix.get_matrix (2, 1)));
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.MatrixTest (),
        new Tests.Matrix3DTest ()
    );
}
