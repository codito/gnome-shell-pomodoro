
/**
 * Helper structure to represent real time or duration
 */
namespace Pomodoro.Timestamp
{
    public const int64 MIN = int64.MIN;
    public const int64 MAX = int64.MAX;

    private int64 frozen_time = -1;

    // TODO: can be a macro
    public int64 from_now ()
    {
        return frozen_time < 0
                ? GLib.get_real_time ()
                : frozen_time;
    }

    // TODO: can be a macro
    public int64 from_seconds (double seconds)
    {
        return (int64) Math.round (seconds * 1000000.0);
    }

    // public int64 from_monotonic_timestamp (int64 monotonic_timestamp)
    // {
    //     return reference_time + monotonic_timestamp;
    // }

    // TODO
    // public int64 from_iso8601 (string text)
    // {
    // }

    // TODO: can be a macro
    public double to_seconds (int64 timestamp)
    {
        return ((double) timestamp) / 1000000.0;
    }

    // TODO
    // public GLib.Date to_date (int64 timestamp)
    // {
    // }

    // TODO
    // public string to_iso8601 (int64 timestamp)
    // {
    // }

    // TODO: can be a macro
    public bool is_finite (int64 timestamp)
    {
        return timestamp > MIN && timestamp < MAX;
    }

    // TODO: can be a macro
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

    // TODO: can be a macro
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
        frozen_time = -1;
    }

    /**
     * Advance frozen time
     */
    public void tick (int64 interval)
    {
        if (frozen_time >= 0) {
            frozen_time += interval;
        }
    }


}
