
// TODO: move to interval.vala
namespace Pomodoro.Interval
{
    public const int64 SECOND = 1000000;
    public const int64 MINUTE = 60 * SECOND;
    public const int64 HOUR   = 60 * MINUTE;
    public const int64 DAY    = 24 * HOUR;
    public const int64 MIN    = int64.MIN;
    public const int64 MAX    = int64.MAX;
}


/**
 * Helper structure to represent real time or duration
 */
namespace Pomodoro.Timestamp
{
    public const int64 UNDEFINED = -1;
    public const int64 MIN       = 0;
    public const int64 MAX       = int64.MAX;

    private int64 frozen_time = UNDEFINED;

    public int64 from_now ()
    {
        return frozen_time < 0
                ? GLib.get_real_time ()
                : frozen_time;
    }

    public int64 from_seconds (double seconds)
    {
        return (int64) Math.round (seconds * (double) Pomodoro.Interval.SECOND);
    }

    // public int64 from_monotonic_timestamp (int64 monotonic_timestamp)
    // {
    //     return reference_time + monotonic_timestamp;
    // }

    // TODO
    // public int64 from_iso8601 (string text)
    // {
    // }

    public double to_seconds (int64 timestamp)
    {
        return ((double) timestamp) / ((double) Pomodoro.Interval.SECOND);
    }

    // TODO
    // public GLib.Date to_date (int64 timestamp)
    // {
    // }

    // TODO
    // public string to_iso8601 (int64 timestamp)
    // {
    // }

    public bool is_finite (int64 timestamp)
    {
        return timestamp > MIN && timestamp < MAX;
    }

    public bool is_infinite (int64 timestamp)
    {
        return timestamp == MIN || timestamp == MAX;
    }

    public int64 add (int64 timestamp,
                      int64 interval)
    {
        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (is_infinite (timestamp)) {
            return timestamp;
        }

        // FIXME: we assume here that `timestamp > 0`

        if (interval >= 0) {
            return interval < MAX - timestamp
                ? timestamp + interval
                : MAX;
        }
        else {
            return -interval < MIN + timestamp
                ? timestamp + interval
                : MIN;
        }
    }

    public int64 subtract (int64 timestamp,
                           int64 interval)
    {
        return add (timestamp, -interval);

        // if (this.is_infinite ()) {
        //     return this;
        // }

        // TODO
    }

    // public int64 multiply (int64 timestamp,
    //                        int64 value)
    // {
    //     if (is_infinite (timestamp)) {
    //         return timestamp;
    //     }

        // TODO
    // }

    // public int64 divide (int64 timestamp,
    //                      int64 value)
    // {
    //     if (is_infinite (timestamp)) {
    //         return timestamp;
    //     }

        // TODO
    // }

    //
    // Functions for unit tests
    //

    /**
     * Fake Pomodoro.get_current_time (). Added for unittesting.
     */
    public void freeze (int64 timestamp = -1)
    {
        if (timestamp < 0) {
            timestamp = Pomodoro.Timestamp.from_now ();
        }

        frozen_time = timestamp;
    }

    /**
     * Revert freeze() call
     */
    public void unfreeze ()
    {
        frozen_time = UNDEFINED;
    }

    /**
     * Advance frozen time
     */
    public int64 tick (int64 interval)
                       requires (interval >= 0)
    {
        if (frozen_time >= 0) {
            frozen_time += interval;
            return frozen_time;
        }
        else {
            return Pomodoro.Timestamp.from_now ();
        }
    }
}
