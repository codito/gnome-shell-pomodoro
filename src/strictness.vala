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
            // TODO: return from settings

            return Pomodoro.Strictness.STRICT;
        }
    }
}
