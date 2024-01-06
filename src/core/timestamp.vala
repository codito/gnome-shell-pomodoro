
// TODO: move to interval.vala
/**
 * Helper functions for handling duration.
 */
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


    public int64 round (int64 interval,
                        int64 unit)
    {
        var unit_half = unit / 2;
        var remainder = interval % unit;

        if (remainder > unit_half) {
            return interval - remainder + unit;
        }

        if (remainder < -unit_half) {
            return interval - remainder - unit;
        }

        return interval - remainder;
    }

    public int64 round_seconds (int64 interval)
    {
        return round (interval, Pomodoro.Interval.SECOND);
    }
}


/**
 * Helper functions for handling time.
 */
namespace Pomodoro.Timestamp
{
    // Special value indicating that timestamp is not set. Assume that timestamps do not go below 0.
    public const int64 UNDEFINED = -1;

    // Value range of a timestamp.
    public const int64 MIN = 0;
    public const int64 MAX = int64.MAX;

    private int64 current_time = UNDEFINED;
    private int64 advance_by = 0;

    public int64 from_now ()
    {
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

    public int64 from_milliseconds_uint (uint milliseconds)
    {
        return (int64) milliseconds * Pomodoro.Interval.MILLISECOND;
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

    public inline bool is_defined (int64 timestamp)
    {
        return timestamp >= Pomodoro.Timestamp.MIN;
    }

    public inline bool is_undefined (int64 timestamp)
    {
        return timestamp < Pomodoro.Timestamp.MIN;
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

    /**
     * Subtract two timestamps. The result is an interval.
     */
    public int64 subtract (int64 timestamp,
                           int64 other)
    {
        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (is_undefined (timestamp)) {
            return 0;
        }

        if (is_undefined (other)) {
            return 0;
        }

        return timestamp - other;
    }

    public int64 subtract_interval (int64 timestamp,
                                    int64 interval)
    {
        return add_interval (timestamp, -interval);
    }

    public int64 round (int64 timestamp,
                        int64 unit)
    {
        return is_defined (timestamp)
            ? Pomodoro.Interval.round (timestamp, unit)
            : Pomodoro.Timestamp.UNDEFINED;
    }

    public int64 round_seconds (int64 timestamp)
    {
        return round (timestamp, Pomodoro.Interval.SECOND);
    }

    /*
     * Functions for unit tests
     */

    /**
     * Freeze `Pomodoro.Timestamp.from_now()` to current time. Used in unittests.
     */
    public int64 freeze ()
    {
        if (Pomodoro.Timestamp.is_undefined (current_time)) {
            current_time = Pomodoro.Timestamp.from_now ();
        }

        return current_time;
    }

    /**
     * Freeze `Pomodoro.Timestamp.from_now()` to a given value. Used in unittests.
     */
    public void freeze_to (int64 timestamp)
    {
        current_time = timestamp;
    }

    /**
     * Revert `freeze()` call. Used in unittests.
     */
    public void thaw ()
    {
        current_time = Pomodoro.Timestamp.UNDEFINED;
    }

    public bool is_frozen ()
    {
        return Pomodoro.Timestamp.is_defined (current_time);
    }

    /**
     * Return current time if frozen.
     */
    public int64 peek ()
    {
        return current_time;
    }

    /**
     * Advance frozen time. Used in unittests.
     */
    public int64 advance (int64 interval)
                          requires (interval >= 0)
    {
        if (!is_frozen ()) {
            Pomodoro.Timestamp.freeze ();
        }

        current_time += interval;

        return current_time;
    }

    /**
     * If frozen, make every call `Pomodoro.Timestamp.from_now ()` advance by given interval. Used in unittests.
     */
    public void set_auto_advance (int64 interval)
                                  requires (interval >= 0)
    {
        advance_by = interval;
    }
}
