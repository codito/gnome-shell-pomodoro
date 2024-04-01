using GLib;


namespace Pomodoro
{
    /**
     * Snapshot of timer/session state at a given time.
     */
    public class Context  // TODO: make it compact class?
    {
        public string?             event_source;
        public int64               timestamp;
        public Pomodoro.TimerState timer_state;
        public Pomodoro.TimeBlock? time_block;
        public Pomodoro.Session?   session;

        private string?            json = null;
        private static string      current_event_source = null;
        private static int64       current_event_source_timestamp = Pomodoro.Timestamp.UNDEFINED;

        public Context.build (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            Pomodoro.ensure_timestamp (ref timestamp);
            Pomodoro.Variables.ensure_initialized ();

            var session_manager = Pomodoro.SessionManager.get_default ();
            var timer = session_manager.timer;

            if (Pomodoro.Timestamp.is_undefined (current_event_source_timestamp)) {
                current_event_source_timestamp = timestamp;
            } else if (current_event_source_timestamp != timestamp) {
                unset_event_source ();
            }

            this.event_source = current_event_source;
            this.timestamp = timestamp;
            this.timer_state = timer.state;
            this.time_block = session_manager.current_time_block;
            this.session = session_manager.current_session;
        }

        // TODO: Calculate Murmur3 hash or serialize this as string
        public uint calculate_checksum ()
        {
            return GLib.str_hash (@"$(this.event_source) $(this.timestamp)");
        }

        /*
         * Event Source
         */

        public static string? get_event_source ()
        {
            return current_event_source;
        }

        public static int64 get_event_source_timestamp ()
        {
            return current_event_source_timestamp;
        }

        public static void set_event_source (string event_source,
                                             int64  timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            current_event_source = event_source;
            current_event_source_timestamp = timestamp;
        }

        public static void unset_event_source ()
        {
            current_event_source = null;
            current_event_source_timestamp = Pomodoro.Timestamp.UNDEFINED;
        }

        /*
         * JSON representation
         */

        private void json_add_timer_state (Json.Builder builder)
        {
            builder.begin_object ();

            builder.set_member_name ("duration");
            builder.add_int_value (this.timer_state.duration);

            builder.set_member_name ("offset");
            builder.add_int_value (this.timer_state.offset);

            builder.set_member_name ("startedTime");
            builder.add_int_value (this.timer_state.started_time);

            builder.set_member_name ("pausedTime");
            builder.add_int_value (this.timer_state.paused_time);

            builder.set_member_name ("finishedTime");
            builder.add_int_value (this.timer_state.finished_time);

            builder.set_member_name ("isRunning");
            builder.add_boolean_value (this.timer_state.is_running ());

            builder.set_member_name ("elapsed");
            builder.add_int_value (this.timer_state.calculate_elapsed (this.timestamp));

            builder.set_member_name ("remaining");
            builder.add_int_value (this.timer_state.calculate_remaining (this.timestamp));

            builder.end_object ();
        }

        private void json_add_time_block (Json.Builder        builder,
                                          Pomodoro.TimeBlock? time_block)
        {
            if (time_block == null) {
                builder.add_null_value ();
                return;
            }

            builder.begin_object ();

            // TODO
            // builder.set_member_name ("id");
            // builder.add_int_value (time_block.id);

            builder.set_member_name ("startTime");
            builder.add_int_value (time_block.start_time);

            builder.set_member_name ("endTime");
            builder.add_int_value (time_block.end_time);

            builder.set_member_name ("state");
            builder.add_string_value (time_block.state.to_string ());

            builder.set_member_name ("status");
            builder.add_string_value (time_block.get_status ().to_string ());

            builder.set_member_name ("gaps");
            builder.begin_array ();
            time_block.foreach_gap (
                (gap) => {
                    builder.begin_object ();

                    builder.set_member_name ("startTime");
                    builder.add_int_value (gap.start_time);

                    builder.set_member_name ("endTime");
                    builder.add_int_value (gap.end_time);

                    // TODO
                    // builder.set_member_name ("reason");
                    // builder.add_int_value (gap.reason.to_string ();

                    builder.end_object ();
                });
            builder.end_array ();

            builder.end_object ();
        }

        public string to_json ()
        {
            if (this.json == null)
            {
                var builder = new Json.Builder ();
                builder.begin_object();

                builder.set_member_name ("timestamp");
                builder.add_int_value (this.timestamp);

                // TODO: if (Config.DEBUG) {
                builder.set_member_name ("_source");
                builder.add_string_value (ensure_string (this.event_source));
                // }

                // Timer state
                builder.set_member_name ("timer");
                this.json_add_timer_state (builder);

                // Current session
                builder.set_member_name ("session");
                builder.begin_array ();

                if (this.session != null) {
                    this.session.@foreach (
                        (time_block) => {
                            // Hide scheduled time-blocks when the timer has stopped. This data can be misleading.
                            // We need those blocks to display session indicator, but here they don't make sense.
                            if (this.time_block == null &&
                                time_block.get_status () == Pomodoro.TimeBlockStatus.SCHEDULED) {
                                return;
                            }

                            this.json_add_time_block (builder, time_block);
                        });
                }

                builder.end_array ();

                builder.end_object ();

                var generator = new Json.Generator ();
	            generator.set_root (builder.get_root ());
                generator.set_pretty (true);

                this.json = generator.to_data (null);
            }

            return this.json;
        }

        /*
         * Variables
         */

        public Pomodoro.Value? evaluate_variable (string variable_name)
        {
            unowned var variable_spec = Pomodoro.find_variable (variable_name);

            return variable_spec != null
                ? variable_spec.evaluate (this)
                : null;
        }
    }
}
