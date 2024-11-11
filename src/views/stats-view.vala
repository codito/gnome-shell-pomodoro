/*
 * Copyright (c) 2017, 2025 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;


namespace Pomodoro
{
    private GLib.DateWeekday first_day_of_week = GLib.DateWeekday.BAD_WEEKDAY;

    /**
     * Based on gtkcalendar.c and https://sourceware.org/glibc/wiki/Locales
     */
    private GLib.DateWeekday get_first_day_of_week ()
    {
        if (!first_day_of_week.valid ())
        {
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
            GLib.info ("week_1stday = %d", week_1stday);
            GLib.info ("first_weekday = %d", first_weekday);
            GLib.info ("first_day_of_week_int = %d", first_day_of_week_int);

            first_day_of_week = first_day_of_week_int == 0
                ? GLib.DateWeekday.SUNDAY
                : GLib.DateWeekday.MONDAY;

            GLib.info ("first_day_of_week=%s valid=%s",
                       first_day_of_week.to_string (),
                       first_day_of_week.valid ().to_string ());
        }

        return first_day_of_week;
    }


    public enum Timeframe
    {
        DAY,
        WEEK,
        MONTH;

        public string to_string ()
        {
            switch (this)
            {
                case DAY:
                    return "day";

                case WEEK:
                    return "week";

                case MONTH:
                    return "month";

                default:
                    assert_not_reached ();
            }
        }

        public static Pomodoro.Timeframe from_string (string? timeframe)
        {
            switch (timeframe)
            {
                case "day":
                    return DAY;

                case "week":
                    return WEEK;

                case "month":
                    return MONTH;

                default:
                    return DAY;
            }
        }

        public string get_label ()
        {
            switch (this)
            {
                case DAY:
                    return _("Day");

                case WEEK:
                    return _("Week");

                case MONTH:
                    return _("Month");

                default:
                    assert_not_reached ();
            }
        }

        public GLib.Date adjust_date (GLib.Date date)
        {
            var adjusted_date = date.copy ();

            switch (this)
            {
                case DAY:
                    break;

                case WEEK:
                    var offset = (int) date.get_weekday () - (int) get_first_day_of_week ();
                    if (offset < 0) {
                        offset += 7;
                    }

                    adjusted_date.subtract_days (offset);
                    break;

                case MONTH:
                    adjusted_date.set_day (1);
                    break;

                default:
                    assert_not_reached ();
            }

            return adjusted_date;
        }
    }


    private GLib.Date get_today_date ()
    {
        var datetime = new GLib.DateTime.now_local ();
        var date = GLib.Date ();

        date.set_dmy ((GLib.DateDay) datetime.get_day_of_month (),
                      (GLib.DateMonth) datetime.get_month (),
                      (GLib.DateYear) datetime.get_year ());
        return date;
    }


    private string format_date (GLib.Date date,
                                string    format)
    {
        var buffer = new char[256];
        var length = date.strftime (buffer, format);

        return (string) buffer[0 : length];
    }


    private static string capitalize_words (string text)
    {
        var string_builder = new GLib.StringBuilder ();
        var capitalize_next = true;
        int index = 0;
        unichar chr;

        while (text.get_next_char (ref index, out chr))
        {
            if (chr == ' ') {
                string_builder.append_unichar (chr);
                capitalize_next = true;
            }
            else if (capitalize_next && chr.islower ()) {
                string_builder.append_unichar (chr.toupper ());
                capitalize_next = false;
            }
            else {
                string_builder.append_unichar (chr);
                capitalize_next = false;
            }
        }

        return string_builder.str;
    }

    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/stats-view.ui")]
    public class StatsView : Adw.Bin
    {
        public Pomodoro.Timeframe timeframe {
            get {
                return this._timeframe;
            }
            set {
                if (this._timeframe == value) {
                    return;
                }

                var date = value.adjust_date (this._date);

                if (this.min_date.valid () && date.compare (this.min_date) < 0) {
                    date = value.adjust_date (this.min_date);
                }

                this._timeframe = value;
                this._date = date;

                if (this.min_date.valid ())
                {
                    this.update_title ();
                    this.update_actions ();

                    this.select_page (this._timeframe,
                                      this._date,
                                      Gtk.StackTransitionType.CROSSFADE);
                }
            }
        }

        public GLib.Date date {
            get {
                return this._date;
            }
        }

        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Label title_label;
        [GtkChild]
        private unowned Gtk.Label subtitle_label;
        [GtkChild]
        private unowned Gtk.Label timeframe_label;
        [GtkChild]
        private unowned Gtk.Stack pages;

        private Pomodoro.Timeframe             _timeframe = Pomodoro.Timeframe.DAY;
        private GLib.Date                      _date;
        private GLib.Date                      min_date;
        private GLib.Date                      max_date;
        private GLib.SimpleAction?             previous_action = null;
        private GLib.SimpleAction?             next_action = null;
        private GLib.SimpleAction?             today_action = null;
        private GLib.SimpleAction?             timeframe_action = null;
        private GLib.Queue<unowned Gtk.Widget> history;
        private Gom.Repository?                repository = null;
        private Pomodoro.SessionManager?       session_manager = null;

        static construct
        {
            set_css_name ("statsview");
        }

        construct
        {
            var today = get_today_date ();

            this.repository      = Pomodoro.Database.get_repository ();
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.history         = new GLib.Queue<unowned Gtk.Widget> ();
            this.max_date        = today;
            this._date           = this._timeframe.adjust_date (today);

            this.initialize_action_group ();

            this.update_title ();
            this.update_actions ();

            this.session_manager.leave_time_block.connect (this.on_leave_time_block);
        }

        private string build_page_name (Pomodoro.Timeframe timeframe,
                                        GLib.Date          date)
        {
            return "%s:%s".printf (timeframe.to_string (), format_date (date, "%d-%m-%Y"));
        }

        private Pomodoro.StatsPage? create_page (Pomodoro.Timeframe timeframe,
                                                 GLib.Date          date)
        {
            switch (timeframe)
            {
                case Pomodoro.Timeframe.DAY:
                    return new Pomodoro.StatsDayPage (this.repository, date);

                case Pomodoro.Timeframe.WEEK:
                    return new Pomodoro.StatsWeekPage (this.repository, date);

                case Pomodoro.Timeframe.MONTH:
                    return new Pomodoro.StatsMonthPage (this.repository, date);

                default:
                    assert_not_reached ();
            }
        }

        private Pomodoro.StatsPage? get_page (string name)
        {
            return this.pages.get_child_by_name (name) as Pomodoro.StatsPage;
        }

        private Pomodoro.StatsPage get_or_create_page (Pomodoro.Timeframe timeframe,
                                                       GLib.Date          date)
        {
            var page_name = this.build_page_name (timeframe, date);
            var page = this.get_page (page_name);

            if (page == null) {
                page = this.create_page (timeframe, date);

                this.pages.add_named ((Gtk.Widget) page, page_name);
            }

            return page;
        }

        private void activate_previous (GLib.SimpleAction action,
                                        GLib.Variant?     parameter)
        {
            switch (this._timeframe)
            {
                case Pomodoro.Timeframe.DAY:
                    this._date.subtract_days (1);
                    break;

                case Pomodoro.Timeframe.WEEK:
                    this._date.subtract_days (7);
                    break;

                case Pomodoro.Timeframe.MONTH:
                    this._date.subtract_months (1);
                    break;

                default:
                    assert_not_reached ();
            }

            this.update_title ();
            this.update_actions ();

            this.select_page (this._timeframe,
                              this._date,
                              Gtk.StackTransitionType.SLIDE_RIGHT);
        }

        private void activate_next (GLib.SimpleAction action,
                                    GLib.Variant?     parameter)
        {
            switch (this._timeframe)
            {
                case Pomodoro.Timeframe.DAY:
                    this._date.add_days (1);
                    break;

                case Pomodoro.Timeframe.WEEK:
                    this._date.add_days (7);
                    break;

                case Pomodoro.Timeframe.MONTH:
                    this._date.add_months (1);
                    break;

                default:
                    assert_not_reached ();
            }

            this.update_title ();
            this.update_actions ();

            this.select_page (this._timeframe,
                              this._date,
                              Gtk.StackTransitionType.SLIDE_LEFT);
        }

        private void activate_today (GLib.SimpleAction action,
                                     GLib.Variant?     parameter)
        {
            this._date = this._timeframe.adjust_date (get_today_date ());

            this.update_title ();
            this.update_actions ();

            this.select_page (this._timeframe,
                              this._date,
                              Gtk.StackTransitionType.CROSSFADE);
        }

        private void activate_timeframe (GLib.SimpleAction action,
                                         GLib.Variant?     parameter)
        {
            this.timeframe = Pomodoro.Timeframe.from_string (parameter.get_string ());
        }

        private void initialize_action_group ()
        {
            var previous_action = new GLib.SimpleAction ("previous", null);
            previous_action.activate.connect (this.activate_previous);

            var next_action = new GLib.SimpleAction ("next", null);
            next_action.activate.connect (this.activate_next);

            var today_action = new GLib.SimpleAction ("today", null);
            today_action.activate.connect (this.activate_today);

            var timeframe_action = new GLib.SimpleAction.stateful (
                    "timeframe",
                    GLib.VariantType.STRING,
                    new GLib.Variant.string (this._timeframe.to_string ()));
            timeframe_action.activate.connect (this.activate_timeframe);

            var action_group = new GLib.SimpleActionGroup ();
            action_group.add_action (previous_action);
            action_group.add_action (next_action);
            action_group.add_action (today_action);
            action_group.add_action (timeframe_action);

            this.previous_action = previous_action;
            this.next_action = next_action;
            this.today_action = today_action;
            this.timeframe_action = timeframe_action;

            this.insert_action_group ("stats", action_group);
        }

        private void update_title ()
        {
            string title;
            string subtitle;

            var current_date = this._timeframe.adjust_date (get_today_date ());

            switch (this._timeframe)
            {
                case Pomodoro.Timeframe.DAY:
                    if (this._date.compare (current_date) == 0) {
                        title = _("Today");
                    }
                    else if (this._date.days_between (current_date) == 1) {
                        title = _("Yesterday");
                    }
                    else if (this._date.get_year () == current_date.get_year ()) {
                        title = capitalize_words (format_date (this._date, "%e %B").chug ());
                    }
                    else {
                        title = capitalize_words (format_date (this._date, "%e %B %Y").chug ());
                    }

                    subtitle = capitalize_words (format_date (this._date, "%A"));
                    break;

                case Pomodoro.Timeframe.WEEK:
                    var week_start = this._date;

                    var week_end = week_start.copy ();
                    week_end.add_days (6);

                    var weeks_ago = week_start.days_between (current_date) / 7;

                    if (week_start.compare (current_date) == 0) {
                        title = _("This week");
                    }
                    else if (weeks_ago >= 0) {
                        title = ngettext (
                            "%u week ago", "%u weeks ago", weeks_ago).printf ((uint) weeks_ago);
                    }
                    else {  // shouldn't happen
                        var week_number = get_first_day_of_week () == GLib.DateWeekday.MONDAY
                                ? week_start.get_monday_week_of_year ()
                                : week_start.get_sunday_week_of_year ();
                        title = _("Week %u").printf (week_number);
                    }

                    if (week_start.get_month () == week_end.get_month ()) {
                        subtitle = capitalize_words ("%s – %s".printf (
                                format_date (week_start, "%e").chug (),
                                format_date (week_end, "%e %B %Y").chug ()));
                    }
                    else {
                        subtitle = capitalize_words ("%s – %s".printf (
                                format_date (week_start, "%e %B").chug (),
                                format_date (week_end, "%e %B %Y").chug ()));
                    }

                    break;

                case Pomodoro.Timeframe.MONTH:
                    if (this.date.get_year () == current_date.get_year ()) {
                        title = capitalize_words (format_date (this._date, "%B"));
                    }
                    else {
                        title = capitalize_words (format_date (this._date, "%B %Y"));
                    }

                    subtitle = "";
                    break;

                default:
                    assert_not_reached ();
            }

            this.title_label.label = title;
            this.subtitle_label.label = subtitle;
            this.subtitle_label.visible = subtitle != "";
        }

        private void select_page (Pomodoro.Timeframe      timeframe,
                                  GLib.Date               date,
                                  Gtk.StackTransitionType transition)
        {
            if (this.stack.visible_child_name != "content")
            {
                return;
            }

            var page      = this.get_or_create_page (timeframe, date);
            var page_name = this.pages.get_page (page).name;

            this.history.remove ((Gtk.Widget) page);
            this.history.push_head ((Gtk.Widget) page);

            while (this.history.length > 3)
            {
                var last_page = this.history.pop_tail ();

                this.pages.remove (last_page);
            }

            this.pages.set_visible_child_full (page_name, transition);
        }

        private void clear_pages ()
        {
            while (this.history.length > 0)
            {
                var last_page = this.history.pop_tail ();

                this.pages.remove (last_page);
            }
        }

        private void update_actions ()
        {
            var reached_min_date = !this.min_date.valid () ||
                    this._date.compare (this._timeframe.adjust_date (this.min_date)) <= 0;
            var reached_max_date = !this.max_date.valid () ||
                    this._date.compare (this._timeframe.adjust_date (this.max_date)) >= 0;

            this.previous_action.set_enabled (!reached_min_date);
            this.next_action.set_enabled (!reached_max_date);
            this.today_action.set_enabled (!reached_max_date);
            this.timeframe_action.set_state (
                    new GLib.Variant.string (this._timeframe.to_string ()));
            this.timeframe_label.label = this._timeframe.get_label ();
        }

        private void update_max_date ()
        {
            this.max_date = get_today_date ();

            this.update_actions ();
        }

        private async GLib.Date fetch_min_date () throws GLib.Error
        {
            var min_date = GLib.Date ();

            // TODO: check daily stats table for latest entry -- aggregate min date?
            /*
            var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
            sorting.add (typeof (Pomodoro.DailyStatsEntry), "date", Gom.SortingMode.ASCENDING);

            this.repository.find_sorted_async.begin (typeof (Pomodoro.DailyStatsEntry),
                                                     null,
                                                     sorting,
                                                     (obj, res) => {
                try {
                    var results = this.repository.find_sorted_async.end (res);

                    if (results.count > 0 && results.fetch_sync (0, 1)) {
                        var first_entry = results.get_index (0) as Pomodoro.Entry;

                        // this.min_datetime = first_entry.get_datetime_local ();

                        min_date.set_dmy (...);
                    }
                }
                catch (GLib.Error error) {
                    GLib.critical ("%s", error.message);
                }

                this.update.callback ();
            });

            yield;
            */

            min_date.set_dmy (30, 10, 2024);  // TODO: remove

            return min_date;
        }

        public override void map ()
        {
            if (!this.min_date.valid ())
            {
                this.stack.visible = false;

                this.fetch_min_date.begin (
                    (obj, res) => {
                        try {
                            this.min_date = this.fetch_min_date.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while fetching stats: %s", error.message);
                        }

                        if (this.min_date.valid ()) {
                            this.stack.set_visible_child_full (
                                    "content",
                                    Gtk.StackTransitionType.NONE);
                            this.select_page (this._timeframe,
                                              this._date,
                                              Gtk.StackTransitionType.NONE);
                        }
                        else {
                            this.stack.set_visible_child_full (
                                    "placeholder",
                                    Gtk.StackTransitionType.NONE);
                            this.clear_pages ();
                        }

                        this.update_actions ();

                        this.stack.visible = true;
                    });
            }
            else {
                this.select_page (this._timeframe,
                                  this._date,
                                  Gtk.StackTransitionType.NONE);
            }

            base.map ();
        }

        private void on_leave_time_block (Pomodoro.TimeBlock time_block)
        {
            this.update_max_date ();
        }

        public override void dispose ()
        {
            if (this.session_manager != null) {
                this.session_manager.leave_time_block.disconnect (this.on_leave_time_block);
                this.session_manager = null;
            }

            base.dispose ();
        }
    }
}
