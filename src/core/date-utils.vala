[CCode (cprefix = "")]
namespace Pomodoro.DateUtils
{
    #if HAVE_ALTMON
    [CCode (cheader_filename = "langinfo.h", cprefix = "", has_type_id = false)]
    private enum NLItem {
	    ALTMON_1,
	    ALTMON_2,
	    ALTMON_3,
	    ALTMON_4,
	    ALTMON_5,
	    ALTMON_6,
	    ALTMON_7,
	    ALTMON_8,
	    ALTMON_9,
	    ALTMON_10,
	    ALTMON_11,
	    ALTMON_12;

	    [CCode (cheader_filename = "langinfo.h", cname = "nl_langinfo")]
	    public extern unowned string to_string ();
    }

    private const NLItem[] MONTHS = {
        NLItem.ALTMON_1,
        NLItem.ALTMON_2,
        NLItem.ALTMON_3,
        NLItem.ALTMON_4,
        NLItem.ALTMON_5,
        NLItem.ALTMON_6,
        NLItem.ALTMON_7,
        NLItem.ALTMON_8,
        NLItem.ALTMON_9,
        NLItem.ALTMON_10,
        NLItem.ALTMON_11,
        NLItem.ALTMON_12
    };
    #else
    private const Posix.NLItem[] MONTHS = {
        Posix.NLItem.MON_1,
        Posix.NLItem.MON_2,
        Posix.NLItem.MON_3,
        Posix.NLItem.MON_4,
        Posix.NLItem.MON_5,
        Posix.NLItem.MON_6,
        Posix.NLItem.MON_7,
        Posix.NLItem.MON_8,
        Posix.NLItem.MON_9,
        Posix.NLItem.MON_10,
        Posix.NLItem.MON_11,
        Posix.NLItem.MON_12
    };
    #endif

    private GLib.DateWeekday first_day_of_week = GLib.DateWeekday.BAD_WEEKDAY;


    public GLib.Date get_today ()
    {
        var datetime = new GLib.DateTime.now_local ();
        var date = GLib.Date ();

        date.set_dmy ((GLib.DateDay) datetime.get_day_of_month (),
                      (GLib.DateMonth) datetime.get_month (),
                      (GLib.DateYear) datetime.get_year ());
        return date;
    }


    public string format_date (GLib.Date date,
                               string    format)
    {
        var buffer = new char[256];
        var length = date.strftime (buffer, format);

        return (string) buffer[0 : length];
    }


    /**
     * Based on gtkcalendar.c and https://sourceware.org/glibc/wiki/Locales
     */
    public GLib.DateWeekday get_first_day_of_week ()
    {
        if (!first_day_of_week.valid ())
        {
            // `Posix.NLTime.WEEK_1STDAY.to_string()` underneath calls `nl_langinfo()`.
            // `nl_langinfo()` produces a string pointer whose address is the number we want.
            // Using the result as a string will cause segfault.
            var week_origin = (long) Posix.NLTime.WEEK_1STDAY.to_string ();
            var week_1stday = 0;

            if (week_origin == 19971130) {  // Sunday
                week_1stday = 0;
            } else if (week_origin == 19971201) {  // Monday
                week_1stday = 1;
            } else {
                GLib.warning ("Unknown value of _NL_TIME_WEEK_1STDAY: %ld", week_origin);
            }

            var first_weekday = (int) Posix.NLTime.FIRST_WEEKDAY.to_string ().data[0];
            var first_day_of_week_int = (week_1stday + first_weekday - 1) % 7;

            first_day_of_week = first_day_of_week_int == 0
                    ? GLib.DateWeekday.SUNDAY
                    : GLib.DateWeekday.MONDAY;
        }

        return first_day_of_week;
    }


    private int get_weekday_number_internal (GLib.DateWeekday weekday)
    {
        switch (weekday)
        {
            case GLib.DateWeekday.MONDAY:
                return 1;

            case GLib.DateWeekday.TUESDAY:
                return 2;

            case GLib.DateWeekday.WEDNESDAY:
                return 3;

            case GLib.DateWeekday.THURSDAY:
                return 4;

            case GLib.DateWeekday.FRIDAY:
                return 5;

            case GLib.DateWeekday.SATURDAY:
                return 6;

            case GLib.DateWeekday.SUNDAY:
                return 7;

            default:
                return -1;
        }
    }


    /**
     * Convert GLib.DateWeekday to integer
     *
     * The result is locale dependant. Starts from 1 - first day of a work week.
     */
    public uint get_weekday_number (GLib.DateWeekday weekday)
    {
        var weekday_number = get_weekday_number_internal (weekday);

        if (weekday_number != -1)
        {
            var first_day_of_week_number = get_weekday_number_internal (get_first_day_of_week ());
            if (first_day_of_week_number == -1) {
                first_day_of_week_number = 7;  // default to SUNDAY as the first day of week
            }

            var result = 1 + weekday_number - first_day_of_week_number;

            if (result < 1) {
                result += 7;
            }

            return (uint) result;
        }
        else {
            return 0U;
        }
    }


    public uint get_month_number (GLib.DateMonth month)
    {
        switch (month)
        {
            case GLib.DateMonth.JANUARY:
                return 1U;

            case GLib.DateMonth.FEBRUARY:
                return 2U;

            case GLib.DateMonth.MARCH:
                return 3U;

            case GLib.DateMonth.APRIL:
                return 4U;

            case GLib.DateMonth.MAY:
                return 5U;

            case GLib.DateMonth.JUNE:
                return 6U;

            case GLib.DateMonth.JULY:
                return 7U;

            case GLib.DateMonth.AUGUST:
                return 8U;

            case GLib.DateMonth.SEPTEMBER:
                return 9U;

            case GLib.DateMonth.OCTOBER:
                return 10U;

            case GLib.DateMonth.NOVEMBER:
                return 11U;

            case GLib.DateMonth.DECEMBER:
                return 12U;

            default:
                return 0U;
        }
    }

    public string get_month_name (GLib.DateMonth month)
    {
        var month_number = get_month_number (month);

        return month_number >= 1
                ? MONTHS[month_number - 1].to_string ()
                : "";
    }
}
