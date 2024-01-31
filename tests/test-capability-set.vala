namespace Tests
{
    [Flags]
    public enum Scenario
    {
        NONE,
        UNAVAILABLE
    }


    public class AntiGravityCapability : Pomodoro.Capability
    {
        public Scenario scenario { get; set; default = Scenario.NONE; }

        public uint initialize_count = 0;
        public uint uninitialize_count = 0;
        public uint enable_count = 0;
        public uint disable_count = 0;
        public uint activate_count = 0;


        public AntiGravityCapability (string            name,
                                      Pomodoro.Priority priority = Pomodoro.Priority.DEFAULT)
        {
            base (name, priority);
        }

        public override void initialize ()
        {
            this.initialize_count++;

            if (Scenario.UNAVAILABLE in this.scenario) {
                this.status = Pomodoro.CapabilityStatus.UNAVAILABLE;
                return;
            }

            base.initialize ();
        }

        public override void uninitialize ()
        {
            this.uninitialize_count++;

            base.uninitialize ();
        }

        public override void enable ()
        {
            this.enable_count++;

            base.enable ();
        }

        public override void disable ()
        {
            this.disable_count++;

            base.disable ();
        }

        public override void activate ()
        {
            this.activate_count++;
        }

        public void set_available (bool value)
        {
            this.status = value
                ? Pomodoro.CapabilityStatus.DISABLED
                : Pomodoro.CapabilityStatus.UNAVAILABLE;
        }
    }


    public class CapabilitySetTest : Tests.TestSuite
    {
        public CapabilitySetTest ()
        {
            this.add_test ("add__null", this.test_add__null);
            this.add_test ("add__disabled", this.test_add__disabled);
            this.add_test ("add__enabled", this.test_add__enabled);
            this.add_test ("add__unavailable", this.test_add__unavailable);
            this.add_test ("add__low_priority_first", this.test_add__low_priority_first);
            this.add_test ("add__low_priority_second", this.test_add__low_priority_second);
            this.add_test ("add__pre_enabled", this.test_add__pre_enabled);
            this.add_test ("add__pre_enabled__unavailable", this.test_add__pre_enabled__unavailable);
            this.add_test ("remove", this.test_remove);
            this.add_test ("capability_becomes_available", this.test_capability_becomes_available);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        /**
         * Adding a capability should automatically make it as preferred capability.
         * It's expected to get initialized.
         */
        public void test_add__null ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();

            var capability = new AntiGravityCapability ("anti-gravity");
            assert_true (capability.status == Pomodoro.CapabilityStatus.NULL);

            capability_set.add (capability);
            assert_true (capability_set.preferred_capability == capability);
            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
        }

        /**
         * Adding a capability that has been already initialized should not initialize it again.
         */
        public void test_add__disabled ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();
            var capability = new AntiGravityCapability ("anti-gravity");

            capability.initialize ();

            capability_set.add (capability);
            assert_true (capability_set.preferred_capability == capability);
            assert_true (capability.status == Pomodoro.CapabilityStatus.DISABLED);
        }

        public void test_add__enabled ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();
            var capability = new AntiGravityCapability ("anti-gravity");

            capability.initialize ();
            capability.enable ();

            capability_set.add (capability);
            assert_true (capability_set.preferred_capability == capability);
            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);
        }

        /**
         * If capability is unavailable `CapabilitySet` should select one that is available, even if it has
         * lower priority.
         */
        public void test_add__unavailable ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();

            var capability_unavailable = new AntiGravityCapability ("unavailable", Pomodoro.Priority.HIGH);
            capability_unavailable.scenario = Scenario.UNAVAILABLE;
            capability_set.add (capability_unavailable);
            assert_true (capability_set.preferred_capability == capability_unavailable);
            assert_true (capability_unavailable.status == Pomodoro.CapabilityStatus.UNAVAILABLE);

            var capability_available = new AntiGravityCapability ("available", Pomodoro.Priority.LOW);
            capability_set.add (capability_available);
            assert_true (capability_set.preferred_capability == capability_available);
            assert_true (capability_available.status == Pomodoro.CapabilityStatus.DISABLED);
        }

        public void test_add__low_priority_first ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();

            var capability_low = new AntiGravityCapability ("low", Pomodoro.Priority.LOW);
            capability_set.add (capability_low);
            assert_true (capability_set.preferred_capability == capability_low);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.DISABLED);

            var capability_high = new AntiGravityCapability ("high", Pomodoro.Priority.HIGH);
            capability_set.add (capability_high);
            assert_true (capability_set.preferred_capability == capability_high);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.DISABLED);

            capability_set.remove (capability_high);
            assert_true (capability_set.preferred_capability == capability_low);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.NULL);

            capability_set.remove (capability_low);
            assert_null (capability_set.preferred_capability);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.NULL);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.NULL);
        }

        public void test_add__low_priority_second ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();

            var capability_high = new AntiGravityCapability ("high", Pomodoro.Priority.HIGH);
            capability_set.add (capability_high);
            assert_true (capability_set.preferred_capability == capability_high);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.DISABLED);

            var capability_low = new AntiGravityCapability ("low", Pomodoro.Priority.LOW);
            capability_set.add (capability_low);
            assert_true (capability_set.preferred_capability == capability_high);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.DISABLED);

            capability_set.remove (capability_high);
            assert_true (capability_set.preferred_capability == capability_low);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.NULL);

            capability_set.remove (capability_low);
            assert_null (capability_set.preferred_capability);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.NULL);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.NULL);
        }

        /**
         * If `enable` property is `true`, capability should be enabled after it got added.
         */
        public void test_add__pre_enabled ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();
            capability_set.enable = true;

            var capability_low = new AntiGravityCapability ("low", Pomodoro.Priority.LOW);
            capability_set.add (capability_low);
            assert_true (capability_set.preferred_capability == capability_low);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.ENABLED);

            var capability_high = new AntiGravityCapability ("high", Pomodoro.Priority.HIGH);
            capability_set.add (capability_high);
            assert_true (capability_set.preferred_capability == capability_high);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.DISABLED);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.ENABLED);

            capability_set.remove (capability_high);
            assert_true (capability_set.preferred_capability == capability_low);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.ENABLED);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.NULL);

            capability_set.remove (capability_low);
            assert_null (capability_set.preferred_capability);
            assert_true (capability_low.status == Pomodoro.CapabilityStatus.NULL);
            assert_true (capability_high.status == Pomodoro.CapabilityStatus.NULL);
        }

        /**
         * If `enable` property is `true`, capability should be enabled after it got added.
         */
        public void test_add__pre_enabled__unavailable ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();
            capability_set.enable = true;

            var capability_unavailable = new AntiGravityCapability ("unavailable", Pomodoro.Priority.HIGH);
            capability_unavailable.scenario = Scenario.UNAVAILABLE;
            capability_set.add (capability_unavailable);
            assert_true (capability_set.preferred_capability == capability_unavailable);
            assert_true (capability_unavailable.status == Pomodoro.CapabilityStatus.UNAVAILABLE);

            var capability_available = new AntiGravityCapability ("available", Pomodoro.Priority.LOW);
            capability_set.add (capability_available);
            assert_true (capability_set.preferred_capability == capability_available);
            assert_true (capability_available.status == Pomodoro.CapabilityStatus.ENABLED);
            assert_true (capability_unavailable.status == Pomodoro.CapabilityStatus.UNAVAILABLE);

            capability_set.remove (capability_available);
            assert_true (capability_set.preferred_capability == capability_unavailable);
            assert_true (capability_unavailable.status == Pomodoro.CapabilityStatus.UNAVAILABLE);
            assert_true (capability_available.status == Pomodoro.CapabilityStatus.NULL);

            capability_set.remove (capability_unavailable);
            assert_null (capability_set.preferred_capability);
            assert_true (capability_unavailable.status == Pomodoro.CapabilityStatus.NULL);
            assert_true (capability_available.status == Pomodoro.CapabilityStatus.NULL);
        }

        public void test_remove ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();
            var capability = new AntiGravityCapability ("anti-gravity");

            capability_set.add (capability);
            assert_true (capability_set.contains (capability));

            capability_set.remove (capability);
            assert_false (capability_set.contains (capability));

            capability_set.remove (capability);
            assert_false (capability_set.contains (capability));
        }

        public void test_capability_becomes_available ()
        {
            var capability_set = new Pomodoro.CapabilitySet ();
            capability_set.enable = true;

            var capability = new AntiGravityCapability ("anti-gravity");
            capability.scenario = Scenario.UNAVAILABLE;
            capability_set.add (capability);
            assert_true (capability_set.preferred_capability == capability);
            assert_true (capability.status == Pomodoro.CapabilityStatus.UNAVAILABLE);

            capability.set_available (true);
            assert_true (capability_set.preferred_capability == capability);
            assert_true (capability.status == Pomodoro.CapabilityStatus.ENABLED);

            capability.set_available (false);
            assert_true (capability_set.preferred_capability == capability);
            assert_true (capability.status == Pomodoro.CapabilityStatus.UNAVAILABLE);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.CapabilitySetTest ()
    );
}
