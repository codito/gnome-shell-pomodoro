namespace Tests
{
    public class TimerViewActionGroupTest : Tests.TestSuite
    {
        public TimerViewActionGroupTest ()
        {
            this.add_test ("new",
                           this.test_new);
            this.add_test ("start",
                           this.test_start);
            this.add_test ("stop",
                           this.test_stop);
        }

        public void test_new ()
        {
            // TODO
            assert_not_reached ();
        }

        public void test_start ()
        {
            // TODO
            assert_not_reached ();
        }

        public void test_stop ()
        {
            // TODO
            assert_not_reached ();
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.TimerViewActionGroupTest ()
    );
}
