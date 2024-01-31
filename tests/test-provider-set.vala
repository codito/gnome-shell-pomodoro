namespace Tests
{
    [Flags]
    public enum Scenario
    {
        DEFAULT,
        UNAVAILABLE,
        TEMPORARILY_UNAVAILABLE,
        ASYNC_INITIALIZE
    }

    public interface AntiGravityProvider : Pomodoro.Provider
    {
        public abstract Scenario scenario { get; construct set; }
    }


    public class SimpleAntiGravityProvider : Pomodoro.Provider, AntiGravityProvider
    {
        public Scenario scenario { get; construct set; }

        public uint initialize_count = 0;
        public uint uninitialize_count = 0;
        public uint enable_count = 0;
        public uint disable_count = 0;

        public SimpleAntiGravityProvider (Scenario scenario = Scenario.DEFAULT)
        {
            GLib.Object (
                scenario: scenario
            );
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.initialize_count++;

            if (Scenario.UNAVAILABLE in this.scenario) {
                this.available = false;
                return;
            }

            if (Scenario.TEMPORARILY_UNAVAILABLE in this.scenario) {
                GLib.Idle.add (() => {
                    this.available = true;

                    return GLib.Source.REMOVE;
                });
                return;
            }

            if (Scenario.ASYNC_INITIALIZE in this.scenario)
            {
                GLib.Idle.add (() => {
                    this.initialize.callback ();

                    return GLib.Source.REMOVE;
                });

                yield;
            }

            this.available = true;
        }

        public override async void uninitialize () throws GLib.Error
        {
            this.uninitialize_count++;
        }

        public override async void enable (GLib.Cancellable? cancellable) throws GLib.Error
        {
            this.enable_count++;
        }

        public override async void disable () throws GLib.Error
        {
            this.disable_count++;
        }

        public override void dispose ()
        {
            base.dispose ();
        }
    }


    public class ProviderSetTest : Tests.TestSuite
    {
        private GLib.MainLoop? main_loop = null;
        private uint           timeout_id = 0;

        public ProviderSetTest ()
        {
            this.add_test ("enable_one__available", this.test_enable_one__available);
            this.add_test ("enable_one__unavailable", this.test_enable_one__unavailable);
            this.add_test ("enable_one__temporarily_unavailable", this.test_enable_one__temporarily_unavailable);
            this.add_test ("enable_one__async_initialize", this.test_enable_one__async_initialize);
        }

        public override void setup ()
        {
            this.main_loop = new GLib.MainLoop ();
        }

        public override void teardown ()
        {
            this.main_loop = null;
        }

        private bool run_main_loop (uint timeout = 1000)
        {
            var success = true;

            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.timeout_id = GLib.Timeout.add (timeout, () => {
                this.timeout_id = 0;
                this.main_loop.quit ();

                success = false;

                return GLib.Source.REMOVE;
            });

            this.main_loop.run ();

            return success;
        }

        private void quit_main_loop ()
        {
            if (this.timeout_id != 0) {
                GLib.Source.remove (this.timeout_id);
                this.timeout_id = 0;
            }

            this.main_loop.quit ();
        }

        public void test_enable_one__available ()
        {
            var providers = new Pomodoro.ProviderSet<AntiGravityProvider> ();
            providers.provider_enabled.connect (() => { this.quit_main_loop (); });

            var provider_low = new SimpleAntiGravityProvider ();
            providers.add (provider_low, Pomodoro.Priority.LOW);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);

            var provider_high = new SimpleAntiGravityProvider ();
            providers.add (provider_high, Pomodoro.Priority.HIGH);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);

            providers.enable_one ();

            assert_true (this.run_main_loop ());

            assert_true (provider_high.available_set);
            assert_true (provider_high.available);
            assert_true (provider_high.enabled);
            assert_cmpuint (provider_high.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_high.enable_count, GLib.CompareOperator.EQ, 1);

            assert_false (provider_low.available_set);
            assert_false (provider_low.available);
            assert_false (provider_low.enabled);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (provider_low.enable_count, GLib.CompareOperator.EQ, 0);

            // Ensure providers are destroyed.
            providers = null;

            var retry_count = 100;

            GLib.Idle.add (
                () => {
                    if (provider_high.uninitialize_count == 0 && retry_count > 0)
                    {
                        retry_count--;

                        return GLib.Source.CONTINUE;
                    }
                    else {
                        this.quit_main_loop ();

                        return GLib.Source.REMOVE;
                    }
                });

            assert_true (this.run_main_loop ());

            assert_false (provider_high.enabled);
            assert_cmpuint (provider_high.disable_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_high.uninitialize_count, GLib.CompareOperator.EQ, 1);

            assert_false (provider_low.enabled);
            assert_cmpuint (provider_low.disable_count, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (provider_low.uninitialize_count, GLib.CompareOperator.EQ, 0);
        }

        public void test_enable_one__unavailable ()
        {
            var providers = new Pomodoro.ProviderSet<AntiGravityProvider> ();
            providers.provider_enabled.connect (() => { this.quit_main_loop (); });

            var provider_low = new SimpleAntiGravityProvider ();
            providers.add (provider_low, Pomodoro.Priority.LOW);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);

            var provider_high = new SimpleAntiGravityProvider (Scenario.UNAVAILABLE);
            providers.add (provider_high, Pomodoro.Priority.HIGH);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);

            providers.enable_one ();
            assert_false (provider_low.enabled);
            assert_false (provider_high.enabled);

            assert_true (this.run_main_loop ());

            assert_true (provider_high.available_set);
            assert_false (provider_high.available);
            assert_false (provider_high.enabled);
            assert_cmpuint (provider_high.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_high.enable_count, GLib.CompareOperator.EQ, 0);

            assert_true (provider_low.available_set);
            assert_true (provider_low.available);
            assert_true (provider_low.enabled);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_low.enable_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_low.uninitialize_count, GLib.CompareOperator.EQ, 0);
        }

        public void test_enable_one__temporarily_unavailable ()
        {
            var providers = new Pomodoro.ProviderSet<AntiGravityProvider> ();
            providers.provider_enabled.connect (() => { this.quit_main_loop (); });

            var provider_low = new SimpleAntiGravityProvider ();
            providers.add (provider_low, Pomodoro.Priority.LOW);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);

            var provider_high = new SimpleAntiGravityProvider (Scenario.TEMPORARILY_UNAVAILABLE);
            providers.add (provider_high, Pomodoro.Priority.HIGH);
            assert_cmpuint (provider_high.initialize_count, GLib.CompareOperator.EQ, 0);

            providers.enable_one ();
            assert_true (this.run_main_loop ());

            assert_true (provider_high.available_set);
            assert_true (provider_high.available);
            assert_true (provider_high.enabled);
            assert_cmpuint (provider_high.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_high.enable_count, GLib.CompareOperator.EQ, 1);

            assert_false (provider_low.available_set);
            assert_false (provider_low.available);
            assert_false (provider_low.enabled);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (provider_low.enable_count, GLib.CompareOperator.EQ, 0);
        }

        public void test_enable_one__async_initialize ()
        {
            var providers = new Pomodoro.ProviderSet<AntiGravityProvider> ();
            providers.provider_enabled.connect (() => { this.quit_main_loop (); });

            var provider_low = new SimpleAntiGravityProvider ();
            providers.add (provider_low, Pomodoro.Priority.LOW);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);

            var provider_high = new SimpleAntiGravityProvider (Scenario.ASYNC_INITIALIZE);
            providers.add (provider_high, Pomodoro.Priority.HIGH);
            assert_cmpuint (provider_high.initialize_count, GLib.CompareOperator.EQ, 0);

            providers.enable_one ();
            assert_true (this.run_main_loop ());

            assert_true (provider_high.available_set);
            assert_true (provider_high.available);
            assert_true (provider_high.enabled);
            assert_cmpuint (provider_high.initialize_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (provider_high.enable_count, GLib.CompareOperator.EQ, 1);

            assert_false (provider_low.available_set);
            assert_false (provider_low.available);
            assert_false (provider_low.enabled);
            assert_cmpuint (provider_low.initialize_count, GLib.CompareOperator.EQ, 0);
            assert_cmpuint (provider_low.enable_count, GLib.CompareOperator.EQ, 0);
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
