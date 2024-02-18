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


namespace Pomodoro
{
    public class NotificationsCapability : Pomodoro.Capability
    {
        private Pomodoro.NotificationManager?                        notification_manager = null;
        private GLib.Cancellable?                                    cancellable = null;
        private Pomodoro.ProviderSet<Pomodoro.NotificationsProvider> providers;

        public NotificationsCapability ()
        {
            base ("notifications", Pomodoro.Priority.DEFAULT);
        }

        private void show_screen_overlay (bool pass_through)
                                          requires (this.notification_manager != null)
        {
            if (this.cancellable != null && !this.cancellable.is_cancelled ()) {
                return;
            }

            var screen_overlay_group = new Pomodoro.LightboxGroup (typeof (Pomodoro.ScreenOverlay));
            var cancellable = new GLib.Cancellable ();

            screen_overlay_group.open.begin (
                cancellable,
                (obj, res) => {
                    try {
                        screen_overlay_group.open.end (res);

                        this.cancellable = null;
                        this.notification_manager.screen_overlay_closed ();
                    }
                    catch (GLib.Error error) {
                        if (!cancellable.is_cancelled ()) {
                            GLib.warning ("Failed to open overlay: %s", error.message);
                            cancellable.cancel ();
                        }
                    }
                });

            if (!cancellable.is_cancelled ()) {
                this.cancellable = cancellable;
                this.notification_manager.screen_overlay_opened ();
            }
        }

        private void on_provider_enabled (Pomodoro.NotificationsProvider provider)
        {
            this.remove_all_details ();

            GLib.info ("Using notifications server: %s %s from %s", provider.name, provider.version, provider.vendor);

            if (provider.has_actions) {
                this.add_detail ("actions");
            }
        }

        private void on_request_screen_overlay_open ()
        {
            this.show_screen_overlay (true);
        }

        private void on_request_screen_overlay_close ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }
        }

        public override void initialize ()
        {
            this.providers = new Pomodoro.ProviderSet<Pomodoro.NotificationsProvider> ();
            this.providers.provider_enabled.connect (this.on_provider_enabled);
            this.providers.add (new Freedesktop.NotificationsProvider ());
            this.providers.enable_one ();

            base.initialize ();
        }

        public override void enable ()
        {
            if (this.notification_manager == null)
            {
                var notification_manager = new Pomodoro.NotificationManager ();
                notification_manager.request_screen_overlay_open.connect (this.on_request_screen_overlay_open);
                notification_manager.request_screen_overlay_close.connect (this.on_request_screen_overlay_close);

                this.notification_manager = notification_manager;
            }

            base.enable ();
        }

        public override void disable ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }

            if (this.notification_manager != null) {
                this.notification_manager.request_screen_overlay_open.disconnect (this.on_request_screen_overlay_open);
                this.notification_manager.request_screen_overlay_close.disconnect (this.on_request_screen_overlay_close);
                this.notification_manager = null;
            }

            base.disable ();
        }

        public override void uninitialize ()
        {
            this.providers = null;

            base.uninitialize ();
        }

        public override void activate ()
        {
            this.show_screen_overlay (false);
        }
    }
}
