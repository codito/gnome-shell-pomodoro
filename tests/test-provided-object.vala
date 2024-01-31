namespace Tests
{
    public enum Scenario
    {
        AVAILABLE = 0,
        UNAVAILABLE = 1,
        FALLBACK = 2
    }


    public interface AntiGravityProvider : Pomodoro.Provider
    {
    }


    public class SimpleAntiGravityProvider : Pomodoro.Provider, AntiGravityProvider
    {
        public bool mark_as_available { get; set; }

        public SimpleAntiGravityProvider (bool mark_as_available = true)
        {
            GLib.Object (
                mark_as_available: mark_as_available
            );
        }

        public override async void initialize (GLib.Cancellable? cancellable) throws GLib.Error
        {
            GLib.Idle.add (() => {
                this.available = this.mark_as_available;

                return GLib.Source.REMOVE;
            });
        }

        public override async void uninitialize () throws GLib.Error
        {
        }

        public override async void enable (GLib.Cancellable? cancellable) throws GLib.Error
        {
        }

        public override async void disable () throws GLib.Error
        {
        }
    }


    public class AntiGravity : Pomodoro.ProvidedObject<AntiGravityProvider>
    {
        public Scenario scenario { get; construct set; }

        public uint setup_count = 0;
        public uint enabled_count = 0;
        public uint disabled_count = 0;

        public AntiGravity (Scenario scenario)
        {
            GLib.Object (
                scenario: scenario
            );
        }

        protected override void setup_providers ()
        {
            this.setup_count++;

            switch (this.scenario)
            {
                case Scenario.AVAILABLE:
                    this.providers.add (new SimpleAntiGravityProvider (true));
                    break;

                case Scenario.UNAVAILABLE:
                    this.providers.add (new SimpleAntiGravityProvider (false));
                    break;

                case Scenario.FALLBACK:
                    this.providers.add (new SimpleAntiGravityProvider (false), Pomodoro.Priority.HIGH);
                    this.providers.add (new SimpleAntiGravityProvider (true), Pomodoro.Priority.LOW);
                    break;

                default:
                    assert_not_reached ();
            }
        }

        protected override void provider_enabled (AntiGravityProvider provider)
        {
            this.enabled_count++;
        }

        protected override void provider_disabled (AntiGravityProvider provider)
        {
            this.disabled_count++;
        }
    }


    public class ProvidedObjectTest : Tests.TestSuite
    {
        private GLib.MainLoop? main_loop = null;
        private uint           timeout_id = 0;

        public ProvidedObjectTest ()
        {
            this.add_test ("available", this.test_available);
            this.add_test ("unavailable", this.test_unavailable);
            this.add_test ("fallback", this.test_fallback);
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

        public void test_available ()
        {
            var anti_gravity = new AntiGravity (Scenario.AVAILABLE);
            anti_gravity.notify["enabled"].connect (() => { this.quit_main_loop (); });

            assert_true (this.run_main_loop ());

            assert_true (anti_gravity.available);
            assert_true (anti_gravity.enabled);
            assert_nonnull (anti_gravity.provider);
            assert_true (anti_gravity.provider.available);
            assert_true (anti_gravity.provider.enabled);

            assert_cmpuint (anti_gravity.setup_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (anti_gravity.enabled_count, GLib.CompareOperator.EQ, 1);
        }

        public void test_unavailable ()
        {
            var anti_gravity = new AntiGravity (Scenario.UNAVAILABLE);
            anti_gravity.provider.notify["available-set"].connect (() => { this.quit_main_loop (); });

            assert_nonnull (anti_gravity.provider);
            assert_false (anti_gravity.provider.available_set);
            assert_false (anti_gravity.provider.available);
            assert_false (anti_gravity.provider.enabled);

            assert_true (this.run_main_loop ());

            assert_false (anti_gravity.provider.available);
            assert_false (anti_gravity.provider.enabled);
            assert_false (anti_gravity.available);

            assert_cmpuint (anti_gravity.setup_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (anti_gravity.enabled_count, GLib.CompareOperator.EQ, 0);
        }

        public void test_fallback ()
        {
            var anti_gravity = new AntiGravity (Scenario.FALLBACK);
            anti_gravity.notify["enabled"].connect (() => { this.quit_main_loop (); });

            assert_true (this.run_main_loop ());

            assert_true (anti_gravity.available);
            assert_true (anti_gravity.enabled);
            assert_nonnull (anti_gravity.provider);
            assert_true (anti_gravity.provider.available);
            assert_true (anti_gravity.provider.enabled);

            assert_cmpuint (anti_gravity.setup_count, GLib.CompareOperator.EQ, 1);
            assert_cmpuint (anti_gravity.enabled_count, GLib.CompareOperator.EQ, 1);
        }
    }
}


public static int main (string[] args)
{
    Tests.init (args);

    return Tests.run (
        new Tests.ProvidedObjectTest ()
    );
}
