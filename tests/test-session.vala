namespace Tests
{
    // private uint8[] list_states (Pomodoro.Session session)
    // {
    //     uint8[] states = {};

    //     session.@foreach ((time_block) => {
    //         states += (uint8) time_block.state;
    //     });

    //     return states;
    // }

    // delegate bool FilterFunc (Pomodoro.TimeBlock time_block);


    private uint count_pomodoros (Pomodoro.Session session)
    {
        var count = 0;

        session.@foreach (time_block => {
            if (time_block.state == Pomodoro.State.POMODORO) {
                count++;
            }
        });

        return count;
    }


    public class SessionTest : Tests.TestSuite
    {
        private Pomodoro.SessionTemplate session_template = Pomodoro.SessionTemplate () {
            pomodoro_duration = 25 * Pomodoro.Interval.MINUTE,
            short_break_duration = 5 * Pomodoro.Interval.MINUTE,
            long_break_duration = 15 * Pomodoro.Interval.MINUTE,
            cycles = 4
        };

        public SessionTest ()
        {
            this.add_test ("new", this.test_new);
            this.add_test ("new_from_template", this.test_new_from_template);

            // TODO: Tests methods for modifying history
            // this.add_test ("prepend", this.test_prepend);
            // this.add_test ("append", this.test_append);
            // this.add_test ("insert", this.test_insert);
            // this.add_test ("insert_before", this.test_insert_before);
            // this.add_test ("insert_after", this.test_insert_after);
            // this.add_test ("replace", this.test_replace);

            this.add_test ("get_first_time_block", this.test_get_first_time_block);
            this.add_test ("get_last_time_block", this.test_get_last_time_block);
            this.add_test ("get_next_time_block", this.test_get_next_time_block);
            this.add_test ("get_previous_time_block", this.test_get_previous_time_block);

            this.add_test ("cycles", this.test_cycles);

            // TODO: Tests methods for modifying ongoing session
            // this.add_test ("extend", this.test_extend);
            // this.add_test ("shorten", this.test_shorten);

            // TODO: Tests for signals
            // this.add_test ("changed_signal", this.test_changed_signal);
            // this.add_test ("time_block_added_signal", this.test_time_block_added_signal);
            // this.add_test ("time_block_removed_signal", this.test_time_block_removed_signal);
            // this.add_test ("time_block_changed_signal", this.test_time_block_changed_signal);

            // TODO: Tests for propagating changes between blocks
            // this.add_test ("time_block_set_start_time", this.test_time_block_set_start_time);
            // this.add_test ("time_block_set_end_time", this.test_time_block_set_end_time);
            // this.add_test ("time_block_set_time_range", this.test_time_block_set_end_time);

            // TODO: methods for saving / restoring in db
        }

        public override void setup ()
        {
            Pomodoro.Timestamp.freeze (2000000000 * Pomodoro.Interval.SECOND);

            // var settings = Pomodoro.get_settings ();
            // settings.set_uint ("pomodoro-duration", POMODORO_DURATION);
            // settings.set_uint ("short-break-duration", SHORT_BREAK_DURATION);
            // settings.set_uint ("long-break-duration", LONG_BREAK_DURATION);
            // settings.set_uint ("pomodoros-per-session", CYCLES_PER_SESSION);
        }

        public override void teardown ()
        {
            Pomodoro.Timestamp.unfreeze ();

            var settings = Pomodoro.get_settings ();
            settings.revert ();
        }

        /**
         * Check constructor `Session()`.
         *
         * Expect session not to have any time-blocks.
         */
        public void test_new ()
        {
            var session = new Pomodoro.Session ();

            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MIN)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (Pomodoro.Timestamp.MAX)
            );

            var first_time_block = session.get_first_time_block ();
            assert_null (first_time_block);

            var last_time_block = session.get_last_time_block ();
            assert_null (last_time_block);
        }

        /**
         * Check constructor `Session.from_template()`.
         *
         * Expect session to have time-blocks defined according to settings.
         */
        public void test_new_from_template ()
        {
            var now = Pomodoro.Timestamp.advance (0);
            var template = this.session_template;
            var session = new Pomodoro.Session.from_template (template);
            // Pomodoro.TimeBlock[] time_blocks = {};

            // session.@foreach ((time_block) => {
            //     time_blocks += time_block;
            // });

            // assert_true (
            //     time_blocks.length == template.cycles * 2
            // );
            // for (uint cycle=0; cycle < template.cycles; cycle++) {
            //     var pomodoro = time_blocks[cycle * 2 + 0];
            //     var break_ = time_blocks[cycle * 2 + 1];

            //     assert_true (pomodoro.state == Pomodoro.State.POMODORO);
            //     assert_true (break_.state == Pomodoro.State.BREAK);
            // }

            assert_cmpuint (session.cycles, GLib.CompareOperator.EQ, template.cycles);

            // assert_cmpmem (
            //     list_session_states (session),
            //     {
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK,
            //         Pomodoro.State.POMODORO,
            //         Pomodoro.State.BREAK
            //     }
            // );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.start_time),
                new GLib.Variant.int64 (now)
            );
            assert_cmpvariant (
                new GLib.Variant.int64 (session.end_time),
                new GLib.Variant.int64 (
                    session.start_time + (
                        template.pomodoro_duration * template.cycles +
                        template.short_break_duration * (template.cycles - 1) +
                        template.long_break_duration
                    )
                )
            );
        }

        public void test_cycles ()
        {
            var session_0 = new Pomodoro.Session ();
            assert_cmpuint (session_0.cycles, GLib.CompareOperator.EQ, 0);

            var session_1 = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    cycles = 1
                }
            );
            assert_cmpuint (session_1.cycles, GLib.CompareOperator.EQ, 1);

            var session_2 = new Pomodoro.Session.from_template (
                Pomodoro.SessionTemplate () {
                    cycles = 2
                }
            );
            assert_cmpuint (session_2.cycles, GLib.CompareOperator.EQ, 2);

            // TODO Test with session starting with a break

            // TODO Test with session starting with undefined block
        }

        public void test_get_first_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (session.get_first_time_block () == time_blocks[0]);

            var empty_session = new Pomodoro.Session ();
            assert_null (empty_session.get_first_time_block ());
        }

        public void test_get_last_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (session.get_last_time_block () == time_blocks[7]);

            var empty_session = new Pomodoro.Session ();
            assert_null (empty_session.get_last_time_block ());
        }

        public void test_get_next_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (
                session.get_next_time_block (time_blocks[0]) == time_blocks[1]
            );
            assert_true (
                session.get_next_time_block (time_blocks[1]) == time_blocks[2]
            );
            assert_null (
                session.get_next_time_block (time_blocks[7])
            );
            assert_null (
                session.get_next_time_block (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO))
            );
        }

        public void test_get_previous_time_block ()
        {
            var time_blocks = new Pomodoro.TimeBlock[0];
            var session     = new Pomodoro.Session.from_template (this.session_template);
            session.@foreach ((time_block) => {
                time_blocks += time_block;
            });

            assert_true (
                session.get_previous_time_block (time_blocks[2]) == time_blocks[1]
            );
            assert_true (
                session.get_previous_time_block (time_blocks[1]) == time_blocks[0]
            );
            assert_null (
                session.get_previous_time_block (time_blocks[0])
            );
            assert_null (
                session.get_previous_time_block (new Pomodoro.TimeBlock (Pomodoro.State.POMODORO))
            );
        }

        // public void test_calculate_pomodoro_break_ratio ()
        // {
        //     var session = new Pomodoro.Session ();
        //
        //     assert_cmpfloat_with_epsilon (
        //         session.calculate_pomodoro_break_ratio (),
        //         double.INFINITY,
        //         0.0001
        //     );
        // }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.SessionTest ()
    );
}
