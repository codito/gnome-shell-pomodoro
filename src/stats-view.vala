/*
 * Copyright (c) 2017 gnome-pomodoro contributors
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
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/stats-view.ui")]
    public class StatsView : Gtk.Box, Gtk.Buildable
    {
        public string mode {
            get {
                return this._mode;
            }
            set {
                this._mode = value;

                if (value == "none")
                {
                    this.stack.visible_child_name = "none";
                }
                else
                {
                    if (this.stack.visible_child_name == "none") {
                        this.stack.visible_child_name = "content";
                    }

                    this.select_page (this.max_datetime);
                }
            }
        }

        [GtkChild]
        private unowned Gtk.Notebook notebook;
        [GtkChild]
        private unowned Gtk.Label title;
        [GtkChild]
        private unowned Gtk.Stack stack;
        [GtkChild]
        private unowned Gtk.Stack pages;

        private Gom.Repository repository;
        private GLib.DateTime? min_datetime;
        private GLib.DateTime? max_datetime;
        private GLib.Queue<unowned Gtk.Widget> history;
        private GLib.SimpleAction previous_action;
        private GLib.SimpleAction next_action;
        private GLib.Binding title_binding;
        private string _mode;

        construct
        {
            this.repository = Pomodoro.get_repository ();
            this.history = new GLib.Queue<unowned Gtk.Widget> ();

            this.mode = "none";

            this.bind_property ("mode",
                                this.notebook,
                                "page",
                                GLib.BindingFlags.BIDIRECTIONAL | GLib.BindingFlags.SYNC_CREATE,
                                transform_mode_to_page,
                                transform_mode_from_page);
            this.bind_property ("mode",
                                this.notebook,
                                "sensitive",
                                GLib.BindingFlags.SYNC_CREATE,
                                transform_mode_to_sensitive);
        }

        public void parser_finished (Gtk.Builder builder)
        {
            this.previous_action = new GLib.SimpleAction ("previous", null);
            this.previous_action.activate.connect (this.activate_previous);

            this.next_action = new GLib.SimpleAction ("next", null);
            this.next_action.activate.connect (this.activate_next);

            var action_group = new GLib.SimpleActionGroup ();
            action_group.add_action (this.previous_action);
            action_group.add_action (this.next_action);

            this.insert_action_group ("stats", action_group);

            base.parser_finished (builder);
        }

        private static bool transform_mode_to_page (GLib.Binding   binding,
                                                    GLib.Value     source_value,
                                                    ref GLib.Value target_value)
        {
            switch (source_value.get_string ())
            {
                case "day":
                    target_value.set_int (0);
                    break;

                case "week":
                    target_value.set_int (1);
                    break;

                case "month":
                    target_value.set_int (2);
                    break;

                case "none":
                    return false;

                default:
                    assert_not_reached ();
            }

            return true;
        }

        private static bool transform_mode_from_page (GLib.Binding   binding,
                                                      GLib.Value     source_value,
                                                      ref GLib.Value target_value)
        {
            switch (source_value.get_int ())
            {
                case 0:
                    target_value.set_string ("day");
                    break;

                case 1:
                    target_value.set_string ("week");
                    break;

                case 2:
                    target_value.set_string ("month");
                    break;

                default:
                    assert_not_reached ();
            }

            return true;
        }

        private static bool transform_mode_to_sensitive (GLib.Binding   binding,
                                                         GLib.Value     source_value,
                                                         ref GLib.Value target_value)
        {
            target_value.set_boolean (source_value.get_string () != "none");

            return true;
        }

        private void activate_previous ()
        {
            var page = this.pages.visible_child as Pomodoro.StatsPage;

            if (page != null) {
                this.select_page (page.get_previous_date ());
            }
        }

        private void activate_next ()
        {
            var page = this.pages.visible_child as Pomodoro.StatsPage;

            if (page != null) {
                this.select_page (page.get_next_date ());
            }
        }

        [GtkCallback]
        private void on_map (Gtk.Widget widget)
        {
            this.update.begin ();
        }

        private async void update ()
        {
            this.max_datetime = new GLib.DateTime.now_local ();

            if (this.min_datetime == null)
            {
                var sorting = (Gom.Sorting) GLib.Object.@new (typeof (Gom.Sorting));
                sorting.add (typeof (Pomodoro.Entry), "datetime-local-string", Gom.SortingMode.ASCENDING);

                this.repository.find_sorted_async.begin (typeof (Pomodoro.Entry),
                                                         null,
                                                         sorting,
                                                         (obj, res) => {
                    try {
                        var group = this.repository.find_sorted_async.end (res);

                        if (group.count > 0 && group.fetch_sync (0, 1)) {
                            var first_entry = group.get_index (0) as Pomodoro.Entry;

                            this.min_datetime = first_entry.get_datetime_local ();
                        }
                        else {
                            this.min_datetime = null;
                        }
                    }
                    catch (GLib.Error error) {
                        this.min_datetime = null;

                        GLib.critical ("%s", error.message);
                    }

                    this.update.callback ();
                });
            }

            yield;

            if (this.min_datetime == null) {
                this.mode = "none";
            }
            else if (this.mode == "none") {
                this.mode = "day";
            }
        }

        /**
         * Normalizes datetime according to mode. Returns null if there are no entries.
         */
        private GLib.DateTime? normalize_datetime (GLib.DateTime? datetime,
                                                   string         mode)
        {
            if (this.min_datetime == null) {
                return null;  /* no entries */
            }

            if (datetime == null) {
                datetime = this.max_datetime;
            }

            switch (mode)
            {
                case "none":
                    break;

                case "day":
                    return new GLib.DateTime.local (datetime.get_year (),
                                                    datetime.get_month (),
                                                    datetime.get_day_of_month (),
                                                    0,
                                                    0,
                                                    0.0);
                case "week":
                    var tmp = new GLib.DateTime.local (datetime.get_year (),
                                                       datetime.get_month (),
                                                       datetime.get_day_of_month (),
                                                       0,
                                                       0,
                                                       0.0);
                    // GLib.DateTime constructor is not happy with negative day numbers,
                    // so a separate add_days() call is needed
                    return tmp.add_days (1 - datetime.get_day_of_week ());
                case "month":
                    return new GLib.DateTime.local (datetime.get_year (),
                                                    datetime.get_month (),
                                                    1,
                                                    0,
                                                    0,
                                                    0.0);
                default:
                    assert_not_reached ();
            }

            return null;
        }

        private string build_page_name (GLib.DateTime datetime,
                                        string        mode)
        {
            return "%s:%s".printf (mode, datetime.format ("%s"));
        }

        private Pomodoro.StatsPage? create_page (GLib.DateTime datetime,
                                                 string        mode)
        {
            switch (mode) {
                case "day":
                    return new Pomodoro.StatsDayPage (this.repository, datetime);

                case "week":
                    return new Pomodoro.StatsWeekPage (this.repository, datetime);

                case "month":
                    return new Pomodoro.StatsMonthPage (this.repository, datetime);

                default:
                    assert_not_reached ();
            }
        }

        private Pomodoro.StatsPage? get_page (string name)
        {
            return this.pages.get_child_by_name (name) as Pomodoro.StatsPage;
        }

        private Pomodoro.StatsPage get_or_create_page (GLib.DateTime datetime,
                                                       string        mode)
        {
            var page_name = this.build_page_name (datetime, mode);
            var page = this.get_page (page_name);

            if (page == null) {
                page = this.create_page (datetime, mode);

                this.pages.add_named (page as Gtk.Widget, page_name);
            }
            
            return page;
        }

        /**
         * Switch to appropriate page specified by datetime, according to current mode
         */
        private void select_page (GLib.DateTime? value)
        {
            var mode         = this.mode;
            var datetime     = this.normalize_datetime (value, mode);
            var min_datetime = this.normalize_datetime (this.min_datetime, mode);
            var max_datetime = this.normalize_datetime (this.max_datetime, mode);

            if (datetime != null)
            {
                var page = this.get_or_create_page (datetime, mode);
                var page_transition = Gtk.StackTransitionType.NONE;

                var current_page = this.pages.visible_child as Pomodoro.StatsPage;
                if (current_page != null) {
                    if (page.get_type () != current_page.get_type ()) {
                        page_transition = Gtk.StackTransitionType.CROSSFADE;
                    }
                    else {
                        page_transition = current_page.date.compare (page.date) < 0
                            ? Gtk.StackTransitionType.SLIDE_LEFT
                            : Gtk.StackTransitionType.SLIDE_RIGHT;
                    }
                }

                this.pages.set_transition_type (page_transition);
                this.pages.set_visible_child (page as Gtk.Widget);

                /* cleanup previous pages */
                this.history.remove (page as Gtk.Widget);
                this.history.push_tail (page as Gtk.Widget);

                while (this.history.length > 3) {
                    this.history.pop_head ().destroy ();
                }

                /* update navigation */
                if (this.title_binding != null) {
                    this.title_binding.unbind ();
                }

                this.title_binding = page.bind_property
                        ("title",
                         this.title,
                         "label",
                         GLib.BindingFlags.SYNC_CREATE);

                this.previous_action.set_enabled
                        (min_datetime != null &&
                         min_datetime.compare (page.get_previous_date ()) <= 0);

                this.next_action.set_enabled
                        (max_datetime != null &&
                         max_datetime.compare (page.get_next_date ()) >= 0);
            }
            else {
                this.previous_action.set_enabled (false);
                this.next_action.set_enabled (false);
            }
        }
    }
}
