
// TODO: move to interval.vala
namespace Pomodoro.Interval
{
    public const int64 MICROSECOND = 1;
    public const int64 MILLISECOND = 1000;
    public const int64 SECOND      = 1000000;
    public const int64 MINUTE      = 60 * SECOND;
    public const int64 HOUR        = 60 * MINUTE;
    public const int64 DAY         = 24 * HOUR;
    public const int64 MIN         = int64.MIN;
    public const int64 MAX         = int64.MAX;


    public int64 add (int64 interval,
                      int64 other)
    {
        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (other > 0) {
            return interval < MAX - other
                ? interval + other
                : MAX;
        }
        else {
            return interval > MIN - other
                ? interval + other
                : MIN;
        }
    }

    public int64 subtract (int64 interval,
                           int64 other)
    {
        return add (interval, -other);
    }
}


/**
 * Helper structure to represent real time or duration
 */
namespace Pomodoro.Timestamp
{
    // Special value. Assume that timestamps do not go below 0.
    public const int64 UNDEFINED = -1;

    // Constants for infinite values.
    public const int64 MIN = 0;
    public const int64 MAX = int64.MAX;

    private int64 current_time = UNDEFINED;
    private int64 advance_by = 0;

    public int64 from_now ()
    {
        GLib.debug ("Timestamp.from_now ()");

        if (current_time >= 0) {
            var tmp = current_time;
            current_time += advance_by;

            return tmp;
        }

        return GLib.get_real_time ();
    }

    public int64 from_seconds (double seconds)
    {
        return (int64) Math.round (seconds * (double) Pomodoro.Interval.SECOND);
    }

    public int64 from_seconds_uint (uint seconds)
    {
        return (int64) seconds * Pomodoro.Interval.SECOND;
    }

    // TODO
    // public int64 from_iso8601 (string text)
    // {
    // }

    public double to_seconds (int64 timestamp)
    {
        return ((double) timestamp) / ((double) Pomodoro.Interval.SECOND);
    }

    public uint to_seconds_uint (int64 timestamp)
    {
        return (uint) (timestamp / Pomodoro.Interval.SECOND).clamp (0, uint.MAX);
    }

    public uint to_seconds_uint32 (int64 timestamp)
    {
        return (uint32) (timestamp / Pomodoro.Interval.SECOND).clamp (0, uint32.MAX);
    }

    public double to_milliseconds (int64 timestamp)
    {
        return ((double) timestamp) / ((double) Pomodoro.Interval.MILLISECOND);
    }

    public uint to_milliseconds_uint (int64 timestamp)
    {
        return (uint) (timestamp / Pomodoro.Interval.MILLISECOND).clamp (0, uint.MAX);
    }

    // TODO
    // public GLib.Date to_date (int64 timestamp)
    // {
    // }

    // TODO
    // public string to_iso8601 (int64 timestamp)
    // {
    // }

    // TODO: remove
    // public bool is_finite (int64 timestamp)
    // {
    //     return timestamp >= MIN;
    // }

    // TODO: remove
    // public bool is_infinite (int64 timestamp)
    // {
    //     return timestamp < MIN;
    // }

    public inline bool is_defined (int64 timestamp)
    {
        return timestamp >= MIN;
    }

    public inline bool is_undefined (int64 timestamp)
    {
        return timestamp < MIN;
    }

    public int64 add (int64 timestamp,
                      int64 other)
    {
        // assert_not_reached ();  // TODO: remove

        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (is_undefined (timestamp)) {
            return timestamp;
        }

        if (is_undefined (other)) {
            return UNDEFINED;
        }

        return timestamp < MAX - other
            ? timestamp + other
            : MAX;
    }

    public int64 add_interval (int64 timestamp,
                               int64 interval)
    {
        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (is_undefined (timestamp)) {
            return UNDEFINED;
        }

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
                           int64 other)
    {
        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (is_undefined (timestamp)) {
            return UNDEFINED;
        }

        if (is_undefined (other)) {
            return UNDEFINED;
        }

        return timestamp > MIN + other
            ? timestamp - other
            : MIN;
    }

    public int64 subtract_interval (int64 timestamp,
                                    int64 interval)
    {
        return add_interval (timestamp, -interval);
    }

    // public int64 multiply (int64 timestamp,
    //                        int64 value)
    // {
    //     if (is_defined (timestamp)) {
    //         return timestamp;
    //     }

        // TODO
    // }

    // public int64 divide (int64 timestamp,
    //                      int64 value)
    // {
    //     if (is_defined (timestamp)) {
    //         return timestamp;
    //     }

        // TODO
    // }

    public int64 round (int64 timestamp,
                        int64 unit)
    {
        var unit_half = unit / 2;
        var remainder = timestamp % unit;

        if (remainder > unit_half) {
            return timestamp - remainder + unit;
        }

        if (remainder < -unit_half) {
            return timestamp - remainder - unit;
        }

        return timestamp - remainder;
    }

    public int64 round_seconds (int64 timestamp)
    {
        return round (timestamp, Pomodoro.Interval.SECOND);
    }

    //
    // Functions for unit tests
    //

    /**
     * Freeze Pomodoro.Timestamp.from_now () to current time. Added for unittesting.
     */
    public void freeze (int64 timestamp = -1,
                        int64 _advance_by = 0)  // TODO: remove arg, return frozen time
    {
        debug ("################# Timestamp.freeze()");

        if (timestamp < 0) {
            timestamp = Pomodoro.Timestamp.from_now ();
        }

        current_time = timestamp;
        advance_by = _advance_by;
    }

    /**
     * Freeze Pomodoro.Timestamp.from_now () to a given value. Added for unittesting.
     */
    public void freeze_to (int64 timestamp,
                           int64 _advance_by = 0)
    {
        debug ("################# Timestamp.freeze_to()");

        current_time = timestamp;
        advance_by = _advance_by;
    }

    /**
     * Revert freeze() call. Added for unittesting.
     */
    public void unfreeze ()  // TODO: rename to "thaw"
    {
        current_time = UNDEFINED;
    }

    public bool is_frozen ()
    {
        return current_time != UNDEFINED;
    }

    /**
     * Return current time if frozen.
     */
    public int64 peek ()
    {
        return current_time;
    }

    /**
     * Advance frozen time. Added for unittesting.
     */
    public int64 advance (int64 interval)
                          requires (interval >= 0)
    {
        if (!is_frozen ()) {
            freeze ();
        }

        current_time += interval;

        debug ("################# Timestamp.advance(): %lld", current_time);

        return current_time;
    }
}
