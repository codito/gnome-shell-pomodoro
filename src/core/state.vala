namespace Pomodoro
{
    /**
     * Pomodoro.State
     *
     * In general, there are main states UNDEFINED, POMODORO and BREAK.
     * BREAK may be resolved to either SHORT_BREAK or LONG_BREAK by the session-manager / scheduler,
     * but can function on its own if session has no cycles.
     */
    public enum State
    {
        UNDEFINED,
        POMODORO,
        BREAK,
        SHORT_BREAK,
        LONG_BREAK;


        public string to_string ()
        {
            switch (this)
            {
                case POMODORO:
                    return "pomodoro";

                case BREAK:
                    return "break";

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
                case "pomodoro":
                    return POMODORO;

                case "break":
                    return BREAK;

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

                case BREAK:
                    return _("Break");

                case SHORT_BREAK:
                    return _("Short Break");

                case LONG_BREAK:
                    return _("Long Break");

                default:
                    assert_not_reached ();
           }
        }

        public bool compare (Pomodoro.State other)
        {
            if (this == BREAK) {
                return other.is_break ();
            }

            if (other == Pomodoro.State.BREAK) {
                return this.is_break ();
            }

            return this == other;
        }

        public bool is_break ()
        {
            return this == BREAK ||
                   this == SHORT_BREAK ||
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
                case SHORT_BREAK:
                    seconds = settings.get_uint ("short-break-duration");
                    break;

                case LONG_BREAK:
                    seconds = settings.get_uint ("long-break-duration");
                    break;

                default:
                    seconds = 0;
                    break;
            }

            return (int64) seconds * Pomodoro.Interval.SECOND;
        }
    }
}
