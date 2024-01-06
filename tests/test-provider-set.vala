namespace Tests
{
    [Flags]
    public enum Scenario
    {
        DEFAULT,
        UNAVAILABLE
    }


    public interface AntiGravityProvider : Pomodoro.Provider
    {
        public abstract Scenario scenario { get; set; }
    }


    public class SimpleAntiGravityProvider : Pomodoro.Provider, AntiGravityProvider
    {
        public Scenario scenario { get; set; default = Scenario.DEFAULT; }

        public uint initialize_count = 0;
        public uint enable_count = 0;
        public uint disable_count = 0;
        public uint destroy_count = 0;

        public SimpleAntiGravityProvider (Scenario scenario = Scenario.DEFAULT)
        {
            GLib.Object (
                scenario: scenario
            );
        }

        public override async void initialize () throws GLib.Error
        {
            this.initialize_count++;

            if (Scenario.UNAVAILABLE in this.scenario) {
                this.available = false;
                return;
            }

            this.available = true;
        }

        public override async void enable () throws GLib.Error
        {
            this.enable_count++;
        }

        public override async void disable () throws GLib.Error
        {
            this.disable_count++;
        }

        public override async void destroy () throws GLib.Error
        {
            this.destroy_count++;
        }
    }

    public class ProviderSetTest : Tests.TestSuite
    {
        public ProviderSetTest ()
        {
            this.add_test ("add__available", this.test_add__available);
            this.add_test ("add__unavailable", this.test_add__unavailable);
            this.add_test ("add__switch_provider", this.test_add__switch_provider);
        }

        public override void setup ()
        {
        }

        public override void teardown ()
        {
        }

        public void test_add__available ()
        {
            var provider_set = new Pomodoro.ProviderSet<AntiGravityProvider> ();

            var provider_low = new SimpleAntiGravityProvider ();
            provider_set.add (provider_low, Pomodoro.ProviderPriority.LOW);
            assert_true (provider_set.preferred_provider == provider_low);

            var provider_high = new SimpleAntiGravityProvider ();
            provider_set.add (provider_high, Pomodoro.ProviderPriority.HIGH);
            assert_false (provider_set.preferred_provider == provider_low);
            assert_true (provider_set.preferred_provider == provider_high);

            provider_set.mark_initialized ();
        }

        public void test_add__unavailable ()
        {
            var provider_set = new Pomodoro.ProviderSet<AntiGravityProvider> ();

            var provider_low = new SimpleAntiGravityProvider (Scenario.UNAVAILABLE);
            provider_set.add (provider_low, Pomodoro.ProviderPriority.LOW);
            assert_false (provider_low.available);
            assert_null (provider_set.preferred_provider);

            var provider_default = new SimpleAntiGravityProvider ();
            provider_set.add (provider_default, Pomodoro.ProviderPriority.DEFAULT);
            assert_true (provider_set.preferred_provider == provider_default);

            var provider_high = new SimpleAntiGravityProvider (Scenario.UNAVAILABLE);
            provider_set.add (provider_high, Pomodoro.ProviderPriority.HIGH);
            assert_true (provider_set.preferred_provider == provider_default);

            provider_set.mark_initialized ();
        }

        public void test_add__switch_provider ()
        {
            var provider_set = new Pomodoro.ProviderSet<AntiGravityProvider> ();

            var provider_low = new SimpleAntiGravityProvider ();
            provider_set.add (provider_low, Pomodoro.ProviderPriority.LOW);
            assert_true (provider_set.preferred_provider == provider_low);

            provider_set.mark_initialized ();

            var provider_default = new SimpleAntiGravityProvider (Scenario.UNAVAILABLE);
            provider_set.add (provider_default, Pomodoro.ProviderPriority.DEFAULT);
            assert_true (provider_set.preferred_provider == provider_low);

            var provider_high = new SimpleAntiGravityProvider ();
            provider_set.add (provider_high, Pomodoro.ProviderPriority.HIGH);
            assert_true (provider_set.preferred_provider == provider_high);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.ProviderSetTest ()
    );
}
