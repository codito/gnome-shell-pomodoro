namespace Pomodoro
{
    [GtkTemplate (ui = "/org/gnomepomodoro/Pomodoro/ui/screen-overlay.ui")]
    public class ScreenOverlay : Pomodoro.Lightbox
    {
        private Gtk.WindowGroup?             window_group;
        private unowned GLib.ListModel?      monitors;
        private ulong                        monitors_changed_id = 0;
        private uint                         update_windows_idle_id = 0;

        construct
        {
            this.window_group = new Gtk.WindowGroup ();
        }

        private void ensure_monitors ()
        {
            var display = this.get_display ();
            var monitors = display?.get_monitors ();

            if (this.monitors != monitors)
            {
                if (this.monitors_changed_id != 0) {
                    this.monitors.weak_unref (this.on_monitors_weak_notify);
                    this.monitors.disconnect (this.monitors_changed_id);
                    this.monitors = null;
                    this.monitors_changed_id = 0;
                }

                this.monitors = display.get_monitors ();
                this.monitors_changed_id = this.monitors.items_changed.connect (this.on_monitors_changed);
                this.monitors.weak_ref (this.on_monitors_weak_notify);
            }
        }

        private void destroy_monitors ()
        {
            if (this.monitors_changed_id != 0) {
                this.monitors.weak_unref (this.on_monitors_weak_notify);
                this.monitors.disconnect (this.monitors_changed_id);
                this.monitors = null;
                this.monitors_changed_id = 0;
            }
        }

        /**
         * A primary monitor used to be defined in X11, now it's managed by a compositor. It's unlikely that
         * we will integrate properly with all compositors.
         *
         * If we can't integrate well with a compositor, we at least want the monitor to be chosen consistently
         * and preferably on a bigger screen.
         */
        private unowned Gdk.Monitor? get_primary_monitor ()
        {
            var display = this.get_display ();

            this.ensure_monitors ();

            #if HAVE_GDK4_X11
                var x11_display = display as Gdk.X11.Display;
                if (x11_display != null) {
                    debug ("Use X11 primary-monitor");
                    return x11_display.get_primary_monitor ();
                }
            #endif

            // TODO: mutter

            // Fall back to selecting the monitor with the biggest area.
            unowned Gdk.Monitor? selected_monitor = null;
            var selected_monitor_area = 0;

            for (var index = 0; index < this.monitors.get_n_items (); index++)
            {
                var monitor = (Gdk.Monitor?) this.monitors.get_item (index);
                var monitor_area = monitor.valid ? monitor.width_mm * monitor.height_mm : 0;

                if (monitor_area > selected_monitor_area) {
                    selected_monitor = monitor;
                    selected_monitor_area = monitor_area;
                }
            }

            if (selected_monitor != null) {
                return selected_monitor;
            }

            // Fall back to using the first monitor.
            for (var index = 0; index < this.monitors.get_n_items (); index++)
            {
                var monitor = (Gdk.Monitor?) this.monitors.get_item (index);

                if (monitor.valid) {
                    unowned Gdk.Monitor? tmp = monitor;
                    return tmp;
                }
            }

            return null;
        }

        private unowned Pomodoro.Lightbox? get_window_for_monitor (Gdk.Monitor monitor)
        {
            unowned Pomodoro.Lightbox? found_window = null;

            if (this._monitor == monitor) {
                return this;
            }

            this.window_group.list_windows ().@foreach (
                (window) => {
                    var lightbox = (Pomodoro.Lightbox) window;

                    if (!window.get_realized ()) {
                        // Ignore windows that are being closed.
                        return;
                    }

                    if (lightbox.monitor == monitor) {
                        found_window = lightbox;
                    }
                });

            return found_window;
        }

        private void create_window (Gdk.Monitor monitor)
        {
            var window = new Pomodoro.Lightbox ();
            window.monitor = monitor;
            // window.set_transient_for (this);

            this.window_group.add_window (window);

            // Keep in mind that new window may steal focus from the main overlay.
            window.present ();
        }

        private void update_windows ()
        {
            // Place main overlay window on primary monitor.
            this.monitor = this.get_primary_monitor ();

            // Track which of windows and monitors do not have a valid pair.
            var unmapped_windows = new GLib.GenericSet<unowned Gtk.Window> (GLib.direct_hash,
                                                                            GLib.direct_equal);
            var unmapped_monitors = new GLib.GenericSet<unowned Gdk.Monitor> (GLib.direct_hash,
                                                                              GLib.direct_equal);

            this.window_group.list_windows ().@foreach (
                (window) => {
                    unmapped_windows.add (window);
                });

            for (var index = 0U; index < this.monitors.get_n_items (); index++)
            {
                var monitor = (Gdk.Monitor?) this.monitors.get_item (index);

                if (monitor.valid)
                {
                    var window = this.get_window_for_monitor (monitor);

                    if (window != null) {
                        unmapped_windows.remove (window);
                    }
                    else {
                        unmapped_monitors.add (monitor);
                    }
                }
            }

            // Update existing windows to use new monitors. We hope that the compositor won't animate them.
            // Close windows that can't be remapped.
            unmapped_windows.@foreach (
                (window) => {
                    unowned GLib.List<weak Gdk.Monitor> monitor_link = unmapped_monitors.get_values ().first ();

                    if (monitor_link != null) {
                        var lightbox = (Pomodoro.Lightbox) window;
                        lightbox.monitor = monitor_link.data;
                        unmapped_monitors.remove (monitor_link.data);
                    }
                    else {
                        window.close ();
                    }
                });

            // Create new windows.
            unmapped_monitors.@foreach (
                (monitor) => {
                    this.create_window (monitor);
                });
        }

        private void queue_update_windows ()
        {
            this.update_windows_idle_id = this.add_tick_callback (() => {
                this.update_windows_idle_id = 0;
                this.update_windows ();

                return GLib.Source.REMOVE;
            });
        }

        private void on_monitors_changed (GLib.ListModel model,
                                          uint           position,
                                          uint           removed,
                                          uint           added)
        {
            this.queue_update_windows ();
        }

        private void on_monitors_weak_notify (GLib.Object object)
        {
            this.monitors = null;
            this.monitors_changed_id = 0;

            this.ensure_monitors ();
        }

        [GtkCallback]
        private void on_lock_button_clicked (Gtk.Button button)
        {
            Pomodoro.lock_screen ();
        }

        [GtkCallback]
        private void on_close_button_clicked (Gtk.Button button)
        {
            this.close ();
        }

        public override void map ()
        {
            this.window_group.add_window (this);
            this.update_windows ();

            base.map ();

            // Reset user idle-time to delay the screen-saver.
            Pomodoro.wake_up_screen ();
        }

        public override void unmap ()
        {
            base.unmap ();

            this.window_group.remove_window (this);
            this.window_group.list_windows ().@foreach (
                (window) => {
                    window.close ();
                });
        }

        public override void dispose ()
        {
            if (this.update_windows_idle_id != 0) {
                this.remove_tick_callback (this.update_windows_idle_id);
                this.update_windows_idle_id = 0;
            }

            this.destroy_monitors ();

            this.window_group = null;

            base.dispose ();
        }
    }
}
