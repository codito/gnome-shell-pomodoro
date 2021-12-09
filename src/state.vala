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
        UNDEFINED = 0,  // aka. stopped
        POMODORO = 1,
        SHORT_BREAK = 2,
        LONG_BREAK = 3;

        // TODO: state-related methods
    }
}
