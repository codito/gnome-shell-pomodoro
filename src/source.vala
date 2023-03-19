using GLib;


namespace Pomodoro
{
    /**
     * Pomodoro.Source
     *
     * Source of actions - whether changes occurs naturally or are triggered manually.
     */
    public enum Source
    {
        UNDEFINED = 0,
        USER = 1,
        TIMER = 2,
        SCHEDULER = 3,
        IDLE_MONITOR = 4
    }
}
