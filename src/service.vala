/*
 * Copyright (c) 2012-2013 gnome-pomodoro contributors
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
    [DBus (name = "org.gnomepomodoro.Pomodoro")]
    public class Service : GLib.Object
    {
        private weak GLib.DBusConnection connection;
        private Pomodoro.Timer timer;
        private GLib.HashTable<string, GLib.Variant> changed_properties;
        private uint idle_id;
        private GLib.Cancellable cancellable;

        public double elapsed {
            get { return this.timer.elapsed; }
        }

        public string state {
            get { return this.timer.state.name; }
        }

        public double state_duration {
            get { return this.timer.state.duration; }
        }

        public bool is_paused {
            get { return this.timer.is_paused; }
        }

        public string version {
            get { return Config.PACKAGE_VERSION; }
        }

        public Service (GLib.DBusConnection connection,
                        Pomodoro.Timer      timer)
        {
            this.connection = connection;
            this.changed_properties = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            this.idle_id = 0;

            this.cancellable = new GLib.Cancellable ();

            this.timer = timer;
            this.timer.state_changed.connect (this.on_timer_state_changed);
            this.timer.notify.connect (this.on_timer_property_notify);
        }

        public void set_state (string name,
                               double timestamp) throws Error
        {
            var state = Pomodoro.TimerState.lookup (name);

            if (timestamp > 0.0) {
                state.timestamp = timestamp;
            }

            if (state != null) {
                this.timer.state = state;
            }

            this.timer.update ();  // TODO: perhaps timer should have "changed" signal
        }

        public void set_state_duration (string name,
                                        double duration) throws Error
        {
            if (this.timer.state.name == name) {
                this.timer.state_duration = double.max (duration, this.timer.elapsed);
            }
            else {
                // XXX: not shure what to do here
            }
        }

        public void show_main_window (string mode,
                                      uint32 timestamp) throws Error
        {
            var application = Pomodoro.Application.get_default ();
            application.show_window (mode, timestamp);
        }

        public void show_preferences (uint32 timestamp) throws Error
        {
            var application = Pomodoro.Application.get_default ();
            application.show_preferences (timestamp);
        }

        public void start () throws Error
        {
            this.timer.start ();
        }

        public void stop () throws Error
        {
            this.timer.stop ();
        }

        public void reset () throws Error
        {
            this.timer.reset ();
        }

        public void pause () throws Error
        {
            this.timer.pause ();
        }

        public void resume () throws Error
        {
            this.timer.resume ();
        }

        public void skip () throws Error
        {
            this.timer.skip ();
        }

        public void quit () throws Error
        {
            this.timer.stop ();

            var application = Pomodoro.Application.get_default ();
            application.quit ();
        }

        private void flush ()
        {
            var builder_properties = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
            var builder_invalid = new GLib.VariantBuilder (GLib.VariantType.STRING_ARRAY);

            /* FIXME: Compile warnings from C compiler */
            this.changed_properties.foreach ((key, value) => {
                builder_properties.add ("{sv}", key, value);
            });
            this.changed_properties.remove_all ();

            try {
                this.connection.emit_signal (null,
                                             "/org/gnomepomodoro/Pomodoro",
                                             "org.freedesktop.DBus.Properties",
                                             "PropertiesChanged",
                                             new GLib.Variant ("(sa{sv}as)",
                                                               "org.gnomepomodoro.Pomodoro",
                                                               builder_properties,
                                                               builder_invalid));
                this.connection.flush_sync (this.cancellable);
            }
            catch (GLib.Error error) {
                GLib.warning ("%s", error.message);
            }

            if (this.idle_id != 0) {
                GLib.Source.remove (this.idle_id);
                this.idle_id = 0;
            }
        }

        private void send_property_changed (string       property_name,
                                            GLib.Variant new_value)
        {
            this.changed_properties.replace (property_name, new_value);

            if (this.idle_id == 0) {
                this.idle_id = GLib.Idle.add (() => {
                    this.flush ();

                    return false;
                });
            }
        }

        private void on_timer_property_notify (GLib.ParamSpec param_spec)
        {
            switch (param_spec.name)
            {
                case "elapsed":
                    this.send_property_changed ("Elapsed",
                                                new GLib.Variant.double (this.elapsed));
                    break;

                case "state":
                    this.send_property_changed ("State",
                                                new GLib.Variant.string (this.state));
                    this.send_property_changed ("StateDuration",
                                                new GLib.Variant.double (this.state_duration));
                    break;

                case "state-duration":
                    this.send_property_changed ("StateDuration",
                                                new GLib.Variant.double (this.state_duration));
                    break;

                case "is-paused":
                    this.send_property_changed ("IsPaused",
                                                new GLib.Variant.boolean (this.is_paused));
                    break;
            }
        }

        private static GLib.HashTable<string, GLib.Variant> serialize_timer_state (Pomodoro.TimerState state)
        {
            var serialized = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            serialized.insert ("name", new GLib.Variant.string (state.name));
            serialized.insert ("elapsed", new GLib.Variant.double (state.elapsed));
            serialized.insert ("duration", new GLib.Variant.double (state.duration));
            serialized.insert ("timestamp", new GLib.Variant.double (state.timestamp));

            return serialized;
        }

        private void on_timer_state_changed (Pomodoro.TimerState state,
                                             Pomodoro.TimerState previous_state)
        {
            this.state_changed (serialize_timer_state (state),
                                serialize_timer_state (previous_state));
        }

        public signal void state_changed (GLib.HashTable<string, GLib.Variant> state,
                                          GLib.HashTable<string, GLib.Variant> previous_state);
    }
}
