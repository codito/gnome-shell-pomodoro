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
        private Pomodoro.ScreenOverlay?                              screen_overlay = null;
        private Pomodoro.ProviderSet<Pomodoro.NotificationsProvider> providers;

        public NotificationsCapability ()
        {
            base ("notifications", Pomodoro.Priority.DEFAULT);
        }

        private void show_screen_overlay (bool  pass_through = true,
                                          int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
                                          requires (this.notification_manager != null)
        {
            if (this.screen_overlay != null && this.screen_overlay.get_mapped ()) {
                return;
            }

            var screen_overlay = new Pomodoro.ScreenOverlay ();
            // screen_overlay.pass_through = pass_through;  // TODO
            screen_overlay.map.connect (() => {
                if (this.screen_overlay != null) {
                    this.notification_manager.screen_overlay_opened ();
                }
            });
            screen_overlay.unmap.connect (() => {
                if (this.screen_overlay != null) {
                    this.screen_overlay = null;
                    this.notification_manager.screen_overlay_closed ();
                }
            });

            this.screen_overlay = screen_overlay;

            if (Pomodoro.Timestamp.is_defined (timestamp)) {
                this.screen_overlay.present_with_time (Pomodoro.Timestamp.to_seconds_uint32 (timestamp));
            }
            else {
                this.screen_overlay.present ();
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
            var notification_manager = new Pomodoro.NotificationManager ();
            notification_manager.open_screen_overlay.connect ((timestamp) => {
                this.show_screen_overlay (true, timestamp);
            });
            notification_manager.close_screen_overlay.connect (() => {
                if (this.screen_overlay != null) {
                    this.screen_overlay.close ();
                }
            });

            this.notification_manager = notification_manager;

            base.enable ();
        }

        public override void disable ()
        {
            if (this.screen_overlay != null) {
                this.screen_overlay.close ();
            }

            this.notification_manager = null;
            this.screen_overlay = null;

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
