/*
 * Copyright (c) 2016 gnome-pomodoro contributors
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


namespace Freedesktop
{
    [DBus (name = "org.freedesktop.Notifications")]
    public interface Notifications : GLib.Object
    {
        public abstract void get_capabilities (out string[] capabilities)
                                               throws Error;
    }
}


namespace Pomodoro
{
    public class NotificationsCapability : Pomodoro.Capability
    {
        private GLib.Settings               settings;
        private Pomodoro.Timer              timer;
        private Pomodoro.ScreenNotification screen_notification;
        private Freedesktop.Notifications   proxy;

        private bool have_actions = false;
        private bool have_persistence = false;

        construct
        {
            string[] capabilities;

            try {
                this.proxy = GLib.Bus.get_proxy_sync<Freedesktop.Notifications> (GLib.BusType.SESSION,
                                                        "org.freedesktop.Notifications",
                                                        "/org/freedesktop/Notifications",
                                                        GLib.DBusProxyFlags.DO_NOT_AUTO_START);
                this.proxy.get_capabilities (out capabilities);

                for (var i=0; i < capabilities.length; i++) {
                    switch (capabilities[i]) {
                        case "actions":
                            this.have_actions = true;
                            break;

                        case "persistence":
                            this.have_persistence = true;
                            break;
                    }
                }
            }
            catch (GLib.Error error) {
            }
        }

        public NotificationsCapability (string name)
        {
            base (name);
        }

        private void notify_pomodoro_start ()
        {
            if (!this.timer.is_paused) {
                this.show_pomodoro_start_notification ();
            }
        }

        private void notify_pomodoro_end ()
        {
            if (!this.timer.is_paused) {
                if (this.settings.get_boolean ("show-screen-notifications")) {
                    this.show_screen_notification ();
                }
                else {
                    this.show_pomodoro_end_notification ();
                }
            }
        }

        private void withdraw_notifications ()
        {
            if (this.screen_notification != null) {
                this.screen_notification.close ();
            }

            GLib.Application.get_default ()
                            .withdraw_notification ("timer");
        }

        private void show_screen_notification ()
        {
            if (this.screen_notification == null) {
                this.screen_notification = new Pomodoro.ScreenNotification ();
                ((Gtk.Widget) this.screen_notification).destroy.connect (() => {
                    this.screen_notification = null;

                    if (!this.timer.is_paused && this.timer.state is Pomodoro.BreakState) {
                        this.show_pomodoro_end_notification ();
                    }
                });
            }

            var application = Pomodoro.Application.get_default ();
            application.add_window (this.screen_notification);

            this.screen_notification.present ();
        }

        private void show_pomodoro_start_notification ()
        {
            var notification = new GLib.Notification (_("Pomodoro"));
            notification.set_body (_("Focus on your task."));
            notification.set_priority (GLib.NotificationPriority.HIGH);

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            if (this.have_actions) {
                notification.add_button (_("Take a break"), "app.timer-skip");
            }

            GLib.Application.get_default ()
                            .send_notification ("timer", notification);
        }

        private void show_pomodoro_end_notification ()
        {
            // TODO: resident notifications won't be updated, might be better not to display scheduled time

            var remaining = (int) Math.ceil (this.timer.remaining);
            var minutes   = (int) Math.round ((double) remaining / 60.0);
            var seconds   = (int) Math.floor (remaining % 60);
            var body      = remaining > 45
                  ? ngettext ("You have %d minute",
                              "You have %d minutes", minutes).printf (minutes)
                  : ngettext ("You have %d second",
                              "You have %d seconds", seconds).printf (seconds);

            var notification = new GLib.Notification ((this.timer.state is Pomodoro.ShortBreakState)
                                                      ? _("Take a break")
                                                      : _("Take a longer break"));
            notification.set_body (body);
            notification.set_priority (GLib.NotificationPriority.HIGH);

            try {
                notification.set_icon (GLib.Icon.new_for_string (Config.PACKAGE_NAME));
            }
            catch (GLib.Error error) {
                GLib.warning (error.message);
            }

            if (this.have_actions)
            {
                notification.set_default_action ("app.show-screen-notification");

                if (this.timer.state is Pomodoro.ShortBreakState) {
                    notification.add_button_with_target_value (_("Lengthen it"),
                                                               "app.timer-switch-state",
                                                               new GLib.Variant.string ("long-break"));
                }
                else {
                    notification.add_button_with_target_value (_("Shorten it"),
                                                               "app.timer-switch-state",
                                                               new GLib.Variant.string ("short-break"));
                }

                notification.add_button_with_target_value (_("Start pomodoro"),
                                                           "app.timer-set-state",
                                                           new GLib.Variant.string ("pomodoro"));
            }

            GLib.Application.get_default ()
                            .send_notification ("timer", notification);
        }

        private void on_settings_changed (GLib.Settings settings,
                                          string        key)
        {
            switch (key)
            {
                case "show-screen-notifications":
                    if (this.timer.state is Pomodoro.BreakState) {
                        this.notify_pomodoro_end ();
                    }

                    break;
            }
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            this.withdraw_notifications ();

            if (state is Pomodoro.PomodoroState) {
                this.notify_pomodoro_start ();
            }
            else if (state is Pomodoro.BreakState) {
                this.notify_pomodoro_end ();
            }
        }

        private void on_timer_state_duration_notify ()
        {
            if (!this.timer.is_paused) {
                if (this.timer.state is Pomodoro.PomodoroState) {
                    this.show_pomodoro_start_notification ();
                }

                if (this.timer.state is Pomodoro.BreakState) {
                    this.show_pomodoro_end_notification ();
                }
            }
        }

        private void on_timer_is_paused_notify ()
        {
            if (this.timer.is_paused) {
                this.withdraw_notifications ();
            }
            else {
                GLib.Idle.add (() => {
                    if (this.timer.state is Pomodoro.PomodoroState) {
                        this.notify_pomodoro_start ();
                    }
                    else if (this.timer.state is Pomodoro.BreakState) {
                        this.notify_pomodoro_end ();
                    }

                    return GLib.Source.REMOVE;
                });
            }
        }

        private void on_show_screen_notification_activate (GLib.SimpleAction action,
                                                           GLib.Variant?     parameter)
        {
            this.show_screen_notification ();
        }

        public override void enable ()
        {
            if (!this.enabled) {
                var show_screen_notification_action = new GLib.SimpleAction ("show-screen-notification", null);
                show_screen_notification_action.activate.connect (this.on_show_screen_notification_activate);

                var application = GLib.Application.get_default ();
                application.add_action (show_screen_notification_action);

                this.timer = Pomodoro.Timer.get_default ();
                this.timer.state_changed.connect_after (this.on_timer_state_changed);
                this.timer.notify["state-duration"].connect (this.on_timer_state_duration_notify);
                this.timer.notify["is-paused"].connect (this.on_timer_is_paused_notify);

                this.settings = Pomodoro.get_settings ().get_child ("preferences");
                this.settings.changed.connect (this.on_settings_changed);

                this.on_timer_state_changed (this.timer.state,
                                             this.timer.state);
            }

            base.enable ();
        }

        public override void disable ()
        {
            if (this.enabled) {
                this.withdraw_notifications ();

                this.timer.state_changed.disconnect (this.on_timer_state_changed);
                this.timer.notify["state-duration"].disconnect (this.on_timer_state_duration_notify);
                this.timer.notify["is-paused"].disconnect (this.on_timer_is_paused_notify);
                this.timer = null;

                this.settings.changed.disconnect (this.on_settings_changed);
                this.settings = null;

                var application = GLib.Application.get_default ();
                application.remove_action ("show-screen-notification");
            }

            base.disable ();
        }
    }
}
