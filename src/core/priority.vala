namespace Pomodoro
{
    public enum Priority
    {
        LOW = 0,
        DEFAULT = 1,
        HIGH = 2;

        public string to_string ()
        {
            switch (this)
            {
                case LOW:
                    return "low";

                case DEFAULT:
                    return "default";

                case HIGH:
                    return "high";

                default:
                    assert_not_reached ();
            }
        }
    }
}
