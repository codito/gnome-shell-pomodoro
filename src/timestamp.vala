
/**
 * Helper structure to represent real time or duration
 */
namespace Pomodoro.Timestamp
{
    public const int64 MIN = int64.MIN;
    public const int64 MAX = int64.MAX;

    // TODO: can be a macro
    public int64 from_now ()
    {
        return GLib.get_real_time ();
    }

    // TODO: can be a macro
    public int64 from_seconds (int64 seconds)
    {
        return seconds * 1000000;
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
    public int64 to_seconds (int64 timestamp)
    {
        return timestamp / 1000000;
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
                      int64 value)
    {
        // TODO: use hardware acceleration for handling overflow https://gcc.gnu.org/onlinedocs/gcc/Integer-Overflow-Builtins.html

        if (is_infinite (timestamp)) {
            return timestamp;
        }

        // FIXME: we assume here that `timestamp > 0`

        if (value >= 0) {
            return value < MAX - timestamp
                ? timestamp + value
                : MAX;
        }
        else {
            return -value < MIN + timestamp
                ? timestamp + value
                : MIN;
        }
    }

    // TODO: can be a macro
    public int64 subtract (int64 timestamp,
                           int64 value)
    {
        return add (timestamp, -value);

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
}
