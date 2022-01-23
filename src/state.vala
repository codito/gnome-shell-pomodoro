namespace Pomodoro
{
    /**
     * Pomodoro.State
     */
    public enum State
    {
        UNDEFINED = 0,
        POMODORO = 1,
        BREAK = 2,
        SHORT_BREAK = 2,  // TODO: remove
        LONG_BREAK = 2;  // TODO: remove

        public string to_string ()
        {
            switch (this)
            {
                case POMODORO:
                    return "pomodoro";

                case BREAK:
                    return "break";

                // case SHORT_BREAK:
                //     return "short-break";

                // case LONG_BREAK:
                //     return "long-break";

                default:
                    return "";
            }
        }

        public static Pomodoro.State from_string (string? state)
        {
            switch (state)
            {
                case "pomodoro":
                    return POMODORO;

                case "break":
                    return BREAK;

                // case "short-break":
                //     return SHORT_BREAK;

                // case "long-break":
                //     return LONG_BREAK;

                default:
                    return UNDEFINED;
            }
        }

        public string get_label ()  // TODO: remove?
        {
            switch (this)
            {
                case UNDEFINED:
                    return _("Stopped");

                case POMODORO:
                    return _("Pomodoro");

                case BREAK:
                    return _("Break");

                // case SHORT_BREAK:
                //     return _("Short Break");

                // case LONG_BREAK:
                //     return _("Long Break");

                default:
                    return "";
           }
        }

        public bool is_break ()  // TODO: remove
        {
            return this == SHORT_BREAK ||
                   this == LONG_BREAK;
        }

        public int64 get_default_duration ()
        {
            var settings = Pomodoro.get_settings ();
            uint seconds;

            switch (this)
            {
                case POMODORO:
                    seconds = settings.get_uint ("pomodoro-duration");
                    break;

                case BREAK:
                    seconds = settings.get_uint ("short-break-duration");
                    break;

                // case LONG_BREAK:
                //     seconds = settings.get_uint ("long-break-duration");
                //     break;

                default:
                    seconds = 0;
                    break;
            }

            return (int64) seconds * Pomodoro.Interval.SECOND;
        }

        public static int64 get_pomodoro_duration ()
        {
            var settings = Pomodoro.get_settings ();
            var seconds = settings.get_uint ("pomodoro-duration");

            return (int64) seconds * Pomodoro.Interval.SECOND;
        }

        public static int64 get_short_break_duration ()
        {
            var settings = Pomodoro.get_settings ();
            var seconds = settings.get_uint ("short-break-duration");

            return (int64) seconds * Pomodoro.Interval.SECOND;
        }

        public static int64 get_long_break_duration ()
        {
            var settings = Pomodoro.get_settings ();
            var seconds = settings.get_uint ("long-break-duration");

            return (int64) seconds * Pomodoro.Interval.SECOND;
        }

    }
}
