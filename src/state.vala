namespace Pomodoro
{
    /**
     * Pomodoro.State
     *
     * We operate within predefined time blocks / timer states. We treat UNDEFINED time blocks somewhat
     * similar to regular ones. It simplifies detection of idle time ("idle" in a sense that timer is not running).
     */
    public enum State
    {
        UNDEFINED = 0,
        POMODORO = 1,
        SHORT_BREAK = 2,
        LONG_BREAK = 3;

        public string to_string ()
        {
            switch (this)
            {
                case UNDEFINED:
                    return "null";  // TODO: change to "undefined"

                case POMODORO:
                    return "pomodoro";

                case SHORT_BREAK:
                    return "short-break";

                case LONG_BREAK:
                    return "long-break";

                default:
                    return "";
            }
        }

        public static Pomodoro.State from_string (string? state)
        {
            switch (state)
            {
                case "null":  // TODO: change to "undefined"
                    return UNDEFINED;

                case "pomodoro":
                    return POMODORO;

                case "short-break":
                    return SHORT_BREAK;

                case "long-break":
                    return LONG_BREAK;

                default:
                    return UNDEFINED;
            }
        }

        public string get_label ()
        {
            switch (this)
            {
                case UNDEFINED:
                    return _("Stopped");

                case POMODORO:
                    return _("Pomodoro");

                case SHORT_BREAK:
                    return _("Short Break");

                case LONG_BREAK:
                    return _("Long Break");

                default:
                    return "";
           }
        }

        public bool is_break ()
        {
            return this == SHORT_BREAK ||
                   this == LONG_BREAK;
        }

        public int64 get_default_duration ()
        {
            var settings = Pomodoro.get_settings ()
                                   .get_child ("preferences");
            double seconds;

            switch (this)
            {
                case POMODORO:
                    seconds = settings.get_double ("pomodoro-duration");
                    break;

                case SHORT_BREAK:
                    seconds = settings.get_double ("short-break-duration");
                    break;

                case LONG_BREAK:
                    seconds = settings.get_double ("long-break-duration");
                    break;

                default:
                    seconds = 0.0;
                    break;
            }

            return (int64) Math.floor (seconds * USEC_PER_SEC);
        }
    }
}
