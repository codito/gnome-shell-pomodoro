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

        public GLib.Type get_scheduler_type ()
        {
            switch (this)
            {
                case STRICT:
                    return typeof (Pomodoro.StrictScheduler);

                // TODO
                // case LENIENT:
                //     return typeof (Pomodoro.LenientScheduler);

                default:
                    assert_not_reached ();
            }
        }
    }
}
