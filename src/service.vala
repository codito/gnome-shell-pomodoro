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
    /*
    [DBus (name = "org.gnomepomodoro.Pomodoro")]
    public class Service : GLib.Object
    {
        private weak GLib.DBusConnection connection;
        private Pomodoro.Timer timer;
        // private GLib.HashTable<string, GLib.Variant> changed_properties;
        // private uint idle_id;
        // private GLib.Cancellable cancellable;

        // public int64 elapsed {
        //     get { return this.timer.get_elapsed (); }
        // }

        public string state {
            owned get { return this.timer.state.to_string (); }
        }

        public int64 state_duration {
            get { return this.timer.time_block.state_duration; }
        }

        public bool is_paused {
            get { return this.timer.is_paused (); }
        }

        public string version {
            get { return Config.PACKAGE_VERSION; }
        }

        public Service (GLib.DBusConnection connection,
                        Pomodoro.Timer      timer)
        {
            this.connection = connection;
            // this.changed_properties = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            // this.idle_id = 0;

            // this.cancellable = new GLib.Cancellable ();

            this.timer = timer;
            this.timer.state_changed.connect (this.on_timer_changed);
        }

        public void set_state (string name,
                               int64  duration = -1,
                               int64  timestamp = -1) throws Error
        {
            // TODO: use session manager here

            // var state = Pomodoro.State.from_string (name);

            // if (timestamp > 0.0) {
            //     state.timestamp = timestamp;
            // }

            // if (state != null) {
            //     this.timer.state = state;
            // }

            // this.timer.update ();  // TODO: perhaps timer should have "changed" signal
        }

        // public void set_state_duration (string name,
        //                                 int64  duration) throws Error
        // {
            // if (this.timer.state.to_string () == name) {
            //
            //    // this.timer.state_duration = double.max (duration, this.timer.get_elapsed ());
            // }
            // else {
            //    // XXX: not shure what to do here
            // }
        // }

        public void show_main_window (string mode,
                                      int64 timestamp = -1) throws Error
        {
            var application = Pomodoro.Application.get_default ();
            application.show_window (mode, timestamp);
        }

        public void show_preferences (int64 timestamp = -1) throws Error
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
            this.timer.reset ();
        }

        // public void reset () throws Error
        // {
        //     this.timer.reset ();
        // }

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
            this.timer.reset ();

            var application = Pomodoro.Application.get_default ();
            application.quit ();
        }

        // private void flush ()
        // {
        //     var builder_properties = new GLib.VariantBuilder (GLib.VariantType.ARRAY);
        //     var builder_invalid = new GLib.VariantBuilder (GLib.VariantType.STRING_ARRAY);
        //
        //     // FIXME: Compile warnings from C compiler
        //     this.changed_properties.foreach ((key, value) => {
        //         builder_properties.add ("{sv}", key, value);
        //     });
        //     this.changed_properties.remove_all ();
        //
        //     try {
        //         this.connection.emit_signal (null,
        //                                      "/org/gnomepomodoro/Pomodoro",
        //                                      "org.freedesktop.DBus.Properties",
        //                                      "PropertiesChanged",
        //                                      new GLib.Variant ("(sa{sv}as)",
        //                                                        "org.gnomepomodoro.Pomodoro",
        //                                                        builder_properties,
        //                                                        builder_invalid));
        //         this.connection.flush_sync (this.cancellable);
        //     }
        //     catch (GLib.Error error) {
        //         GLib.warning ("%s", error.message);
        //     }
        //
        //     if (this.idle_id != 0) {
        //         GLib.Source.remove (this.idle_id);
        //         this.idle_id = 0;
        //     }
        // }

        // private void send_property_changed (string       property_name,
        //                                     GLib.Variant new_value)
        // {
        //     this.changed_properties.replace (property_name, new_value);
        //
        //     if (this.idle_id == 0) {
        //         this.idle_id = GLib.Idle.add (() => {
        //             this.flush ();
        //
        //             return false;
        //         });
        //     }
        // }

        // private void on_timer_property_notify (GLib.ParamSpec param_spec)
        // {
        //     switch (param_spec.name)
        //     {
        //         case "elapsed":
        //             this.send_property_changed ("Elapsed",
        //                                         new GLib.Variant.double (this.elapsed));
        //             break;
        //
        //         case "state":
        //             this.send_property_changed ("State",
        //                                         new GLib.Variant.string (this.state));
        //             this.send_property_changed ("StateDuration",
        //                                         new GLib.Variant.double (this.state_duration));
        //             break;
        //
        //         case "state-duration":
        //             this.send_property_changed ("StateDuration",
        //                                         new GLib.Variant.double (this.state_duration));
        //             break;
        //
        //         case "is-paused":
        //             this.send_property_changed ("IsPaused",
        //                                         new GLib.Variant.boolean (this.is_paused));
        //             break;
        //     }
        // }

        private static GLib.HashTable<string, GLib.Variant> serialize_timer_properties (Pomodoro.Timer timer)
        {
            var serialized = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            serialized.insert ("state", new GLib.Variant.string (timer.state.to_string ()));
            serialized.insert ("duration", new GLib.Variant.int64 (timer.duration));
            serialized.insert ("timestamp", new GLib.Variant.int64 (timer.timestamp));
            serialized.insert ("offset", new GLib.Variant.int64 (timer.offset));
            serialized.insert ("is-paused", new GLib.Variant.int64 (timer.is_paused ()));

            return serialized;
        }

        private void on_timer_changed (Pomodoro.Timer timer)
        {
            this.changed (serialize_timer_state (timer));
        }

        public signal void changed (GLib.HashTable<string, GLib.Variant> state);
    }
    */




    [DBus (name = "org.gnomepomodoro.Pomodoro")]
    public class ApplicationService : GLib.Object
    {
        public string version {
            get { return Config.PACKAGE_VERSION; }
        }

        private weak GLib.DBusConnection connection;
        private Pomodoro.Application     application;

        public ApplicationService (GLib.DBusConnection  connection,
                                   Pomodoro.Application application)
        {
            this.connection = connection;
            this.application = application;
        }

        public void show_main_window (string mode,
                                      uint32 timestamp) throws Error
        {
            this.application.show_window (mode, timestamp);
        }

        public void show_preferences (uint32 timestamp) throws Error
        {
            this.application.show_preferences (timestamp);
        }

        public void quit () throws Error
        {
            this.application.quit ();
        }
    }


    public errordomain TimerServiceError
    {
        INVALID_ELAPSED,
    }


    /**
     * Timer service provides similar functionality to the timer view in the app.
     */
    [DBus (name = "org.gnomepomodoro.Pomodoro")]
    public class TimerService : GLib.Object
    {
        // public uint session_id {
        //     get { return this.timer.time_block.session.id; }
        // }

        // public uint time_block_id {
        //     get { return this.timer.time_block.id; }
        // }

        // [Description(nick = "age in years", blurb = "This is the person's age in years")]
        // public string state {  // TODO: make this as an object?
        //     owned get { return this.timer.state.to_string (); }
        // }

        // public double state_duration {
        //     get { return this.timer.state.duration; }
        // }

        // public bool is_paused {
        //     get { return this.timer.is_paused; }
        // }

        // public int session { get; }  // how many pomodoros passed since start / long-break
        // public int sessions_per_cycle { get; }  // how many pomodoros per cycle

        // public Stats stats { get; }  // TODO: mainly on today

        private Pomodoro.Timer timer;
        private Pomodoro.SessionManager session_manager;


        public TimerService (GLib.DBusConnection connection)
        {
            this.session_manager = Pomodoro.SessionManager.get_default ();
            this.timer           = Pomodoro.Timer.get_default ();

            this.timer.state_changed.connect (this.on_timer_state_changed);
            this.timer.finished.connect (this.on_timer_finished);
            // this.timer.suspended.connect (this.on_timer_suspended);

            // TODO: disconnect handlers at exit
        }

        public void start () throws GLib.Error
        {
            this.timer.start ();
        }

        public void stop () throws GLib.Error
        {
            this.timer.reset ();
        }

        public void pause () throws GLib.Error
        {
            this.timer.pause ();
        }

        public void resume () throws GLib.Error
        {
            this.timer.resume ();
        }

        // Skip current state and jump to the next.
        // Optionally, hint that state should me marked as completed.
        public void skip () throws GLib.Error
        {
            this.session_manager.advance ();
        }

        // TODO: rewind()

        // TODO: Timer.reset() should work differently than SessionManager.reset()
        // Reset timer and current session.
        // If timer is stopped then it remains so.
        // When you reset. The elapsed time does not get counted
        // public void reset () throws GLib.Error
        // {
        //     this.timer.reset ();
        // }

        public int64 get_elapsed (int64 timestamp = -1) throws GLib.Error
        {
            return this.timer.calculate_elapsed (timestamp);
        }

        // public get_state () throws GLib.Error
        // {
        //     return this.serialize_state (this.timer.state);
        // }

        // Method for jumping to a desired state
        // public void set_state (string state_name) throws Error
        // {
        //     var state = Pomodoro.State.from_string (state_name);

            // if (state == null) {
            //     throw new GLib.Error ("Unrecognized state name: '%s'".printf (state_name));
            // }

            // TODO
            // this.timer.state = state;
        // }

        // Modify timer state. Client is not aware of state_duration of other states, so its use is likely
        // limited to modifying the current state, for usecases like:
        //   - extending or shorting state duration,
        //   - resetting the elapsed time.
        // public void set_state_full (string state_name,
        //                             int64  state_duration,
        //                             int64  elapsed = 0,
        //                             bool   is_paused = false) throws GLib.Error
        // {
        //     var state = Pomodoro.State.from_string (state_name);

            // if (state == null) {
            //     throw GLib.Error ("Unrecognized state name: '%s'".printf (state_name));
            // }

        //     if (elapsed < 0) {
        //         throw new Pomodoro.TimerServiceError.INVALID_ELAPSED ("Elapsed time can't be negative");
        //     }

            // if (state != null) {
            //     // TODO: we should inhibit this.on_timer_state_changed until all properties are set
            //     this.timer.state = state;
            // }
            // TODO
        // }

        // Signal emitted by gnome-pomodoro asking clients to update all data.
        // It may be due to state change or due to system events like resuming from suspend.
        // public signal void synchronize ();

        public signal void finished ();

        // "changed" signal is emmited if one of timer params have changed.
        public signal void changed (GLib.HashTable<string, GLib.Variant> data);


        private static GLib.HashTable<string, GLib.Variant> serialize_timer_state (Pomodoro.Timer timer)
        {
            // var time_block_data = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            // time_block_data.insert ("state", new GLib.Variant.string (timer.state.to_string ()));

            var data = new GLib.HashTable<string, GLib.Variant> (str_hash, str_equal);
            // data.insert ("time-block", new GLib.Variant.int64 ());
            // data.insert ("state", new GLib.Variant.string (timer.state.to_string ()));
            data.insert ("duration", new GLib.Variant.int64 (timer.duration));
            // data.insert ("timestamp", new GLib.Variant.int64 (timer.timestamp));
            // data.insert ("offset", new GLib.Variant.int64 (timer.offset));
            data.insert ("is-paused", new GLib.Variant.boolean (timer.is_paused ()));

            return data;
        }

        private void on_timer_state_changed ()
        {
            this.changed (serialize_timer_state (this.timer));
        }

        private void on_timer_finished ()
        {
            this.finished ();
        }

        // private void on_timer_suspended ()
        // {
        //     this.synchronize ();
        // }
    }

    [DBus (name = "org.gnomepomodoro.Pomodoro")]
    public class SessionService : GLib.Object
    {
    }

}
