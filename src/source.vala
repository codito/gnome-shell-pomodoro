using GLib;


namespace Pomodoro
{
    /**
     * Pomodoro.Source
     *
     * Source of actions - whether changes occures naturally or are triggered manually.
     */
    public enum Source
    {
        UNDEFINED = 0,
        USER = 1,
        TIMER = 2,
        IDLE_MONITOR = 3,
        OTHER = 4
    }
}
