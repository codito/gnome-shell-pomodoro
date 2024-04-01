namespace Tests
{
    public class EventActionTest : Tests.TestSuite
    {
        private string uuid;

        public EventActionTest ()
        {
            this.add_test ("load", this.test_load);
            this.add_test ("save", this.test_save);
        }

        public override void setup ()
        {
            this.uuid = GLib.Uuid.string_random ();
        }

        public void test_load ()
        {
            var settings = new GLib.Settings.with_path (
                    "org.gnomepomodoro.Pomodoro.actions.action",
                    @"/org/gnomepomodoro/Pomodoro/actions/$(this.uuid)/");
            settings.set_enum ("trigger", Pomodoro.ActionTrigger.EVENT);
            settings.set_boolean ("enabled", true);
            settings.set_string ("display-name", "Event Action");
            settings.set_strv ("events", {"start", "stop"});
            settings.set_string ("condition", "isRunning");
            settings.set_boolean ("wait-for-completion", true);
            settings.set_string ("command", "echo Event");
            settings.set_string ("working-directory", "/tmp");
            settings.set_boolean ("use-subshell", true);
            settings.set_boolean ("pass-input", true);

            var action = new Pomodoro.EventAction (this.uuid);
            action.load (settings);

            assert_true (action.enabled);
            assert_cmpstr (action.display_name, GLib.CompareOperator.EQ, "Event Action");
            assert_cmpstrv (action.event_names, {"start", "stop"});
            assert_nonnull (action.condition);
            assert_cmpstr (action.condition.to_string (), GLib.CompareOperator.EQ, "isRunning");
            assert_true (action.wait_for_completion);
            assert_cmpstr (action.command.line, GLib.CompareOperator.EQ, "echo Event");
            assert_cmpstr (action.command.working_directory, GLib.CompareOperator.EQ, "/tmp");
            assert_true (action.command.use_subshell);
            assert_true (action.command.pass_input);
        }

        public void test_save ()
        {
            var settings = new GLib.Settings.with_path (
                    "org.gnomepomodoro.Pomodoro.actions.action",
                    @"/org/gnomepomodoro/Pomodoro/actions/$(uuid)/");

            var action = new Pomodoro.EventAction (this.uuid);
            action.display_name = "Event Action";
            action.event_names = {"start", "stop"};
            action.condition = new Pomodoro.Variable ("is-running");
            action.wait_for_completion = true;
            action.command = new Pomodoro.Command ("echo Event");
            action.command.working_directory = "/tmp";
            action.command.use_subshell = true;
            action.command.pass_input = true;
            action.save (settings);

            assert_true (settings.get_boolean ("enabled"));
            assert_cmpstr (settings.get_string ("display-name"), GLib.CompareOperator.EQ, "Event Action");
            assert_cmpstrv (settings.get_strv ("events"), {"start", "stop"});
            assert_cmpstr (settings.get_string ("condition"), GLib.CompareOperator.EQ, "isRunning");
            assert_true (settings.get_boolean ("wait-for-completion"));
            assert_cmpstr (settings.get_string ("command"), GLib.CompareOperator.EQ, "echo Event");
            assert_cmpstr (settings.get_string ("working-directory"), GLib.CompareOperator.EQ, "/tmp");
            assert_true (settings.get_boolean ("use-subshell"));
            assert_true (settings.get_boolean ("pass-input"));
        }
    }


    public class ConditionActionTest : Tests.TestSuite
    {
        private string uuid;

        public ConditionActionTest ()
        {
            this.add_test ("load", this.test_load);
            this.add_test ("save", this.test_save);
        }

        public override void setup ()
        {
            this.uuid = GLib.Uuid.string_random ();
        }

        public void test_load ()
        {
            var settings = new GLib.Settings.with_path (
                    "org.gnomepomodoro.Pomodoro.actions.action",
                    @"/org/gnomepomodoro/Pomodoro/actions/$(this.uuid)/");
            settings.set_enum ("trigger", Pomodoro.ActionTrigger.CONDITION);
            settings.set_boolean ("enabled", true);
            settings.set_string ("display-name", "Condition Action");
            settings.set_string ("condition", "isRunning");
            settings.set_string ("command", "echo Enter");
            settings.set_string ("exit-command", "echo Exit");
            settings.set_string ("working-directory", "/tmp");
            settings.set_boolean ("use-subshell", true);
            settings.set_boolean ("pass-input", true);

            var action = new Pomodoro.ConditionAction (this.uuid);
            action.load (settings);

            assert_true (action.enabled);
            assert_cmpstr (action.display_name, GLib.CompareOperator.EQ, "Condition Action");
            assert_nonnull (action.condition);
            assert_cmpstr (action.condition.to_string (), GLib.CompareOperator.EQ, "isRunning");
            assert_cmpstr (action.enter_command.line, GLib.CompareOperator.EQ, "echo Enter");
            assert_cmpstr (action.enter_command.working_directory, GLib.CompareOperator.EQ, "/tmp");
            assert_true (action.enter_command.use_subshell);
            assert_true (action.enter_command.pass_input);
            assert_cmpstr (action.exit_command.line, GLib.CompareOperator.EQ, "echo Exit");
            assert_cmpstr (action.exit_command.working_directory, GLib.CompareOperator.EQ, "/tmp");
            assert_true (action.exit_command.use_subshell);
            assert_true (action.exit_command.pass_input);
        }

        public void test_save ()
        {
            var settings = new GLib.Settings.with_path (
                    "org.gnomepomodoro.Pomodoro.actions.action",
                    @"/org/gnomepomodoro/Pomodoro/actions/$(this.uuid)/");

            var action = new Pomodoro.ConditionAction (this.uuid);
            action.display_name = "Condition Action";
            action.condition = new Pomodoro.Variable ("is-running");
            action.enter_command = new Pomodoro.Command ("echo Enter");
            action.exit_command = new Pomodoro.Command ("echo Exit");
            action.exit_command.working_directory = action.enter_command.working_directory = "/tmp";
            action.exit_command.use_subshell = action.enter_command.use_subshell = true;
            action.exit_command.pass_input = action.enter_command.pass_input = true;
            action.save (settings);

            assert_cmpuint (settings.get_enum ("trigger"),
                            GLib.CompareOperator.EQ,
                            Pomodoro.ActionTrigger.CONDITION);
            assert_true (settings.get_boolean ("enabled"));
            assert_cmpstr (settings.get_string ("display-name"), GLib.CompareOperator.EQ, "Condition Action");
            assert_cmpstr (settings.get_string ("condition"), GLib.CompareOperator.EQ, "isRunning");
            assert_cmpstr (settings.get_string ("command"), GLib.CompareOperator.EQ, "echo Enter");
            assert_cmpstr (settings.get_string ("exit-command"), GLib.CompareOperator.EQ, "echo Exit");
            assert_cmpstr (settings.get_string ("working-directory"), GLib.CompareOperator.EQ, "/tmp");
            assert_true (settings.get_boolean ("use-subshell"));
            assert_true (settings.get_boolean ("pass-input"));
        }
    }


    public class ActionListModelTest : Tests.TestSuite
    {
        public ActionListModelTest ()
        {
            // this.add_test ("save_action", this.test_save_action);
            this.add_test ("update_action", this.test_update_action);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_update_action ()
        {
            var session_manager = Pomodoro.SessionManager.get_default ();
            var timer           = session_manager.timer;

            var action_1 = new Pomodoro.EventAction ("00000000-0000-0000-0000-000000000000");
            action_1.display_name = "Sample Action";
            action_1.command = new Pomodoro.Command ("echo Started");
            action_1.event_names = {"start"};

            var action_2 = new Pomodoro.EventAction (action_1.uuid);
            action_2.display_name = "Changed Action";
            action_2.command = new Pomodoro.Command ("echo Resumed");
            action_2.event_names = {"resume"};

            var manager = new Pomodoro.ActionManager ();
            manager.model.save_action (action_1);
            manager.model.save_action (action_2);

            var action = (Pomodoro.EventAction?) manager.model.lookup (action_1.uuid);
            assert_cmpstr (action.display_name, GLib.CompareOperator.EQ, action_2.display_name);
            assert_cmpstr (action.command.line, GLib.CompareOperator.EQ, action_2.command.line);
            assert_cmpstrv (action.event_names, action_2.event_names);
        }
    }


    public class ActionManagerTest : Tests.TestSuite
    {
        public ActionManagerTest ()
        {
            // TODO
            // this.add_test ("action_added", this.test_action_added);
            // this.add_test ("action_removed", this.test_action_removed);
            // this.add_test ("action_replaced", this.test_action_replaced);
            // this.add_test ("action_disabled", this.test_action_disabled);

            // this.add_test ("event_action", this.test_event_action);
            // this.add_test ("condition_action", this.test_condition_action);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_event_action ()
        {
            var session_manager = Pomodoro.SessionManager.get_default ();
            var timer           = session_manager.timer;

            var action = new Pomodoro.EventAction ();
            action.display_name = "Sample Action";
            action.command = new Pomodoro.Command ("echo -en '\\007'");
            // action.add_event ();

            // action.command.execute

            // try {
            //     action.command.validate ();
            // }
            // catch (Pomodoro.ExecutionError error) {
            // }


            var manager = new Pomodoro.ActionManager ();
            manager.model.save_action (action);


            timer.start ();
            //

            timer.pause ();


        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.EventActionTest (),
        new Tests.ConditionActionTest (),
        new Tests.ActionListModelTest (),
        new Tests.ActionManagerTest ()
    );
}
