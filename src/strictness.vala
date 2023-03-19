namespace Pomodoro
{
    public enum Strictness
    {
        STRICT,
        LENIENT;

        /**
         * Return a fallback strictness if none is specified.
         */
        public static Pomodoro.Strictness get_default ()
        {
            var settings = Pomodoro.get_settings ();

            return settings.get_enum ("strictness");
        }
    }
}
