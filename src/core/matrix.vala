namespace Pomodoro
{
    /**
     * Class for representing a variable-size vector.
     *
     * It's just for pure convenience to have vector operations at hand.
     * Underneath `data` is stored as `GArray` - Vala by default does that for dynamic arrays,
     * on top of Vector being a compact class... It's not very efficient.
     *
     * XXX: Consider making functions for simple arrays (`double[]`)
     */
    [Compact]  // TODO: reconsider simple struct
    public class Vector
    {
        public double[] data;  // XXX: try to store as 2D array to avoid GArray

        public Vector (uint length)
        {
            this.data = new double[length];
        }

        public Vector.from_array (double[] array)
        {
            this.data = array;
        }

        public Pomodoro.Vector copy ()
        {
            var result = new Pomodoro.Vector (this.data.length);
            result.data = this.data;

            return result;
        }

        private inline bool validate_index (ref int i)
        {
            if (i < 0) {
                i = this.data.length + i;
            }

            return i < this.data.length;
        }

        public double @get (int    i,
                            double default_value = double.NAN)
        {
            return this.validate_index (ref i)
                    ? this.data[i]
                    : default_value;
        }

        public void @set (int    i,
                          double value)
        {
            if (this.validate_index (ref i)) {
                this.data[i] = value;
            }
            else {
                GLib.warning ("Vector index %u is out of bounds", i);
            }
        }

        public bool equals (Pomodoro.Vector other)
        {
            if (this.data.length != data.length) {
                return false;
            }

            for (var i = 0; i < this.data.length; i++)
            {
                if ((this.data[i] - other.data[i]).abs () > double.EPSILON) {
                    return false;
                }
            }

            return true;
        }

        public bool add (Pomodoro.Vector other)
        {
            if (other.data.length != this.data.length) {
                return false;
            }

            for (var i = 0; i < this.data.length; i++) {
                this.data[i] += other.data[i];
            }

            return true;
        }

        public double sum ()
        {
            var result = 0.0;

            for (var i = 0; i < this.data.length; i++)
            {
                result += this.data[i];
            }

            return result;
        }

        public double min ()
        {
            var result = this.data[0];

            for (var i = 0; i < this.data.length; i++)
            {
                if (result > this.data[i]) {
                    result = this.data[i];
                }
            }

            return result;
        }

        public double max ()
        {
            var result = this.data[0];

            for (var i = 0; i < this.data.length; i++)
            {
                if (result < this.data[i]) {
                    result = this.data[i];
                }
            }

            return result;
        }
    }


    /**
     * Class for representing a variable-size 2D array. It's intended for large data, that's why
     * it's not a `struct`.
     *
     * If you intend to do maths, consider `Gsl.Matrix` or `Cogl.Matrix`.
     *
     * API is inspired by `numpy`.
     */
    [Compact]
    public class Matrix
    {
        private const int DIMENSIONS = 2;

        public uint[]    shape;
        public double[,] data;

        public Matrix (uint shape_0,
                       uint shape_1)
        {
            this.shape = { shape_0, shape_1 };
            this.data  = new double[shape_0, shape_1];
        }

        public Matrix.from_array (double[,] array)
        {
            this.shape = { array.length[0], array.length[1] };
            this.data  = array;
        }

        public Pomodoro.Matrix copy ()
        {
            var result = new Pomodoro.Matrix (this.shape[0], this.shape[1]);
            result.data = this.data;

            return result;
        }

        private inline bool validate_axis (ref int axis)
        {
            if (axis < 0) {
                axis = DIMENSIONS + axis;
            }

            return axis < DIMENSIONS;
        }

        private inline bool validate_indices (ref int i,
                                              ref int j)
        {
            if (i < 0) {
                i = this.data.length[0] + i;
            }

            if (j < 0) {
                j = this.data.length[1] + j;
            }

            return i < this.data.length[0] &&
                   j < this.data.length[1];
        }

        private inline bool validate_index (ref int axis,
                                            ref int index)
        {
            if (!this.validate_axis (ref axis)) {
                return false;
            }

            if (index < 0) {
                index = (int) this.shape[axis] + index;
            }

            return index < (int) this.shape[axis];
        }

        public void resize (uint shape_0,
                            uint shape_1)
        {
            var intersect_0 = uint.min (shape_0, this.shape[0]);
            var intersect_1 = uint.min (shape_1, this.shape[1]);
            var data        = new double[shape_0, shape_1];

            for (var i = 0; i < intersect_0; i++)
            {
                for (var j = 0; j < intersect_1; j++) {
                    data[i, j] = this.data[i, j];
                }
            }

            this.data  = data;
            this.shape = { shape_0, shape_1 };
        }

        public double @get (int    i,
                            int    j,
                            double default_value = double.NAN)
        {
            return this.validate_indices (ref i, ref j)
                    ? this.data[i, j]
                    : default_value;
        }

        public void @set (int    i,
                          int    j,
                          double value)
        {
            if (this.validate_indices (ref i, ref j)) {
                this.data[i, j] = value;
            }
            else {
                GLib.warning ("Matrix indices %u, %u are out of bounds", i, j);
            }
        }

        public bool equals (Pomodoro.Matrix other)
        {
            if (this.shape[0] != other.shape[0] || this.shape[1] != other.shape[1]) {
                return false;
            }

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    if ((this.data[i, j] - other.data[i, j]).abs () > double.EPSILON) {
                        return false;
                    }
                }
            }

            return true;
        }

        public bool add (Pomodoro.Matrix other)
        {
            if (other.shape[0] != this.shape[0] || other.shape[1] != this.shape[1]) {
                return false;
            }

            for (var i = 0; i < this.shape[0]; i++)
            {
                for (var j = 0; j < this.shape[1]; j++)
                {
                    this.data[i, j] += other.data[i, j];
                }
            }

            return true;
        }

        public inline Vector? get_vector_internal (int axis,
                                                   int index)
        {
            switch (axis)
            {
                case 0:
                    var data = new double[this.data.length[1]];

                    for (var j = 0; j < this.data.length[1]; j++) {
                        data[j] = this.data[index, j];
                    }

                    return new Pomodoro.Vector.from_array (data);

                case 1:
                    var data = new double[this.data.length[0]];

                    for (var i = 0; i < this.data.length[0]; i++) {
                        data[i] = this.data[i, index];
                    }

                    return new Pomodoro.Vector.from_array (data);

                default:
                    assert_not_reached ();
            }
        }

        public Pomodoro.Vector? get_vector (int axis,
                                            int index)
        {
            if (!this.validate_index (ref axis, ref index)) {
                return null;
            }

            return this.get_vector_internal (axis, index);
        }

        public double sum ()
        {
            var result = 0.0;

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    result += this.data[i, j];
                }
            }

            return result;
        }

        public double min ()
        {
            var result = this.data[0, 0];

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    if (result > this.data[i, j]) {
                        result = this.data[i, j];
                    }
                }
            }

            return result;
        }

        public double max ()
        {
            var result = this.data[0, 0];

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    if (result < this.data[i, j]) {
                        result = this.data[i, j];
                    }
                }
            }

            return result;
        }

        /**
         * Split an array into multiple sub-vectors along given axis.
         */
        public Vector[] unstack (int axis = -1)
        {
            assert (this.validate_axis (ref axis));

            for (var index = 0; index < DIMENSIONS; index++)
            {
                if (index < axis) {
                    shape[index] = this.shape[index];
                }
                else if (index > axis) {
                    shape[index - 1] = this.shape[index];
                }
            }

            var result = new Vector[this.shape[axis]];

            for (var index = 0; index < this.shape[axis]; index++)
            {
                result[index] = this.get_vector_internal (axis, index);
            }

            return result;
        }

        public string to_representation ()
        {
            var string_builder = new GLib.StringBuilder ();

            string_builder.append ("{\n");

            for (var i = 0; i < this.data.length[0]; i++)
            {
                if (i > 0) {
                    string_builder.append (",\n");
                }

                string_builder.append ("    { ");

                for (var j = 0; j < this.data.length[1]; j++)
                {
                    if (j > 0) {
                        string_builder.append (", ");
                    }

                    string_builder.append ("%.3g".printf (this.data[i, j]));
                }

                string_builder.append (" }");
            }

            string_builder.append ("\n}");

            return string_builder.str;
        }
    }


    /**
     * Class for representing a variable-size 3D array. It's intended for large data, that's why
     * it's not a `struct`.
     *
     * API is inspired by `numpy`.
     */
    [Compact]
    public class Matrix3D
    {
        private const int DIMENSIONS = 3;

        public uint[]     shape;
        public double[,,] data;

        public Matrix3D (uint shape_0, uint shape_1, uint shape_2)
        {
            this.shape = { shape_0, shape_1, shape_2 };
            this.data  = new double[shape_0, shape_1, shape_2];
        }

        public Matrix3D.from_array (double[,,] array)
        {
            this.shape = { array.length[0], array.length[1], array.length[2] };
            this.data  = array;
        }

        private inline bool validate_axis (ref int axis)
        {
            if (axis < 0) {
                axis = DIMENSIONS + axis;
            }

            return axis < DIMENSIONS;
        }

        private inline bool validate_indices (ref int i,
                                              ref int j,
                                              ref int k)
        {
            if (i < 0) {
                i = this.data.length[0] + i;
            }

            if (j < 0) {
                j = this.data.length[1] + j;
            }

            if (k < 0) {
                k = this.data.length[2] + k;
            }

            return i < this.data.length[0] &&
                   j < this.data.length[1] &&
                   k < this.data.length[2];
        }

        private inline bool validate_index (ref int axis,
                                            ref int index)
        {
            if (!this.validate_axis (ref axis)) {
                return false;
            }

            if (index < 0) {
                index = (int) this.shape[axis] + index;
            }

            return index < (int) this.shape[axis];
        }

        public void resize (uint shape_0,
                            uint shape_1,
                            uint shape_2)
        {
            var intersect_0 = uint.min (shape_0, this.shape[0]);
            var intersect_1 = uint.min (shape_1, this.shape[1]);
            var intersect_2 = uint.min (shape_2, this.shape[2]);
            var data        = new double[shape_0, shape_1, shape_2];

            for (var i = 0; i < intersect_0; i++)
            {
                for (var j = 0; j < intersect_1; j++)
                {
                    for (var k = 0; k < intersect_2; k++) {
                        data[i, j, k] = this.data[i, j, k];
                    }
                }
            }

            this.data  = data;
            this.shape = { shape_0, shape_1, shape_2 };
        }

        public double @get (int    i,
                            int    j,
                            int    k,
                            double default_value = double.NAN)
        {
            return this.validate_indices (ref i, ref j, ref k)
                    ? this.data[i, j, k]
                    : default_value;
        }

        public void @set (int    i,
                          int    j,
                          int    k,
                          double value)
        {
            if (this.validate_indices (ref i, ref j, ref k)) {
                this.data[i, j, k] = value;
            }
            else {
                GLib.warning ("Matrix indices %u, %u, %u are out of bounds", i, j, k);
            }
        }

        public bool equals (Pomodoro.Matrix3D other)
        {
            if (this.shape[0] != other.shape[0] ||
                this.shape[1] != other.shape[1] ||
                this.shape[2] != other.shape[2])
            {
                return false;
            }

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    for (var k = 0; k < this.data.length[2]; k++)
                    {
                        if ((this.data[i, j, k] - other.data[i, j, k]).abs () > double.EPSILON) {
                            return false;
                        }
                    }
                }
            }

            return true;
        }

        public inline Matrix? get_matrix_internal (int axis,
                                                   int index)
        {
            switch (axis)
            {
                case 0:
                    var data = new double[this.data.length[1], this.data.length[2]];

                    for (var j = 0; j < this.data.length[1]; j++)
                    {
                        for (var k = 0; k < this.data.length[2]; k++) {
                            data[j, k] = this.data[index, j, k];
                        }
                    }

                    return new Pomodoro.Matrix.from_array (data);

                case 1:
                    var data = new double[this.data.length[0], this.data.length[2]];

                    for (var i = 0; i < this.data.length[0]; i++)
                    {
                        for (var k = 0; k < this.data.length[2]; k++) {
                            data[i, k] = this.data[i, index, k];
                        }
                    }

                    return new Pomodoro.Matrix.from_array (data);

                case 2:
                    var data = new double[this.data.length[0], this.data.length[1]];

                    for (var i = 0; i < this.data.length[0]; i++)
                    {
                        for (var j = 0; j < this.data.length[1]; j++) {
                            data[i, j] = this.data[i, j, index];
                        }
                    }

                    return new Pomodoro.Matrix.from_array (data);

                default:
                    assert_not_reached ();
            }
        }

        public Pomodoro.Matrix? get_matrix (int axis,
                                            int index)
        {
            if (!this.validate_index (ref axis, ref index)) {
                return null;
            }

            return this.get_matrix_internal (axis, index);
        }

        public double sum ()
        {
            var result = 0.0;

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    for (var k = 0; k < this.data.length[2]; k++)
                    {
                        result += this.data[i, j, k];
                    }
                }
            }

            return result;
        }

        public double min ()
        {
            var result = this.data[0, 0, 0];

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    for (var k = 0; k < this.data.length[2]; k++)
                    {
                        if (result > this.data[i, j, k]) {
                            result = this.data[i, j, k];
                        }
                    }
                }
            }

            return result;
        }

        public double max ()
        {
            var result = this.data[0, 0, 0];

            for (var i = 0; i < this.data.length[0]; i++)
            {
                for (var j = 0; j < this.data.length[1]; j++)
                {
                    for (var k = 0; k < this.data.length[2]; k++)
                    {
                        if (result < this.data[i, j, k]) {
                            result = this.data[i, j, k];
                        }
                    }
                }
            }

            return result;
        }

        /**
         * Split an array into multiple sub-arrays along given axis.
         *
         * For example, splitting along the last axis. You can visualise it as an array of vectors.
         * Splitting will replace those vectors with numeric values, and will return same number of
         * matrices as the vectors length.
         */
        public Matrix[] unstack (int axis = -1)
        {
            assert (validate_axis (ref axis));

            uint[] shape = { 0, 0 };

            for (var index = 0; index < DIMENSIONS; index++)
            {
                if (index < axis) {
                    shape[index] = this.shape[index];
                }
                else if (index > axis) {
                    shape[index - 1] = this.shape[index];
                }
            }

            var result = new Matrix[this.shape[axis]];

            for (var index = 0; index < this.shape[axis]; index++) {
                result[index] = this.get_matrix (axis, index);
            }

            return result;
        }
    }
}
