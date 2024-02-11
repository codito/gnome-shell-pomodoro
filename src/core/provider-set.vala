namespace Pomodoro
{
    /**
     * Time between the start of provider initialization to resolution of availability.
     */
    private const int64 AVAILABILITY_TIMEOUT = Pomodoro.Interval.MILLISECOND * 100;
    private const int64 AVAILABILITY_TIMEOUT_TOLERANCE = Pomodoro.Interval.MILLISECOND * 20;


    private enum SelectionMode
    {
        NONE,
        ONE,
        ALL
    }


    private enum ProviderStatus
    {
        NOT_INITIALIZED,
        INITIALIZING,
        UNINITIALIZING,
        DISABLING,
        DISABLED,
        ENABLING,
        ENABLED;

        public bool is_transient ()
        {
            switch (this)
            {
                case INITIALIZING:
                case UNINITIALIZING:
                case DISABLING:
                case ENABLING:
                    return true;

                default:
                    return false;
            }
        }
    }


    private class ProviderInfo
    {
        public Pomodoro.Provider             instance;
        public Pomodoro.Priority             priority;
        public Pomodoro.ProviderStatus       status = Pomodoro.ProviderStatus.NOT_INITIALIZED;
        public bool                          selected = false;
        public bool                          destroying = false;
        public GLib.Cancellable?             cancellable = null;
        public int64                         initialization_time = Pomodoro.Timestamp.UNDEFINED;

        public ProviderInfo (Pomodoro.Provider instance,
                             Pomodoro.Priority priority)
        {
            this.instance = instance;
            this.priority = priority;
        }

        public int64 get_availability_timeout (ref int64 monotonic_time)
        {
            if (this.instance.available_set) {
                return 0;
            }

            if (Pomodoro.Timestamp.is_undefined (this.initialization_time)) {
                return 0;
            }

            if (Pomodoro.Timestamp.is_undefined (monotonic_time)) {
                monotonic_time = GLib.get_monotonic_time ();
            }

            return monotonic_time - this.initialization_time;
        }

        ~ProviderInfo ()
        {
            if (this.cancellable != null) {
                this.cancellable.cancel ();
                this.cancellable = null;
            }

            this.instance = null;
        }
    }


    public class ProviderSet<T> : GLib.Object
    {
        private GLib.GenericSet<Pomodoro.ProviderInfo> providers = null;
        private Pomodoro.SelectionMode                 _selection_mode = Pomodoro.SelectionMode.NONE;
        private uint                                   update_selection_timeout_id = 0;
        private bool                                   selection_invalid = false;
        private bool                                   updating_selection = false;

        construct
        {
            this.providers = new GLib.GenericSet<Pomodoro.ProviderInfo> (direct_hash, direct_equal);
        }

        /**
         * Manage provider according to its status.
         *
         * It should be called after every async action or status changed.
         */
        private void check_provider_status (Pomodoro.ProviderInfo provider_info)
        {
            var provider = provider_info.instance;

            // Each action should call check_provider_status() at the end, so if the status is transient
            // we can ignore it.
            if (provider_info.status.is_transient ()) {
                return;
            }

            if (provider_info.selected && !provider_info.destroying)
            {
                if (provider_info.status == Pomodoro.ProviderStatus.NOT_INITIALIZED)
                {
                    provider_info.status = Pomodoro.ProviderStatus.INITIALIZING;
                    provider_info.cancellable = new GLib.Cancellable ();
                    provider_info.initialization_time = GLib.get_monotonic_time ();
                    provider.initialize.begin (
                        provider_info.cancellable,
                        (obj, res) => {
                            try {
                                provider.initialize.end (res);
                                provider_info.status = Pomodoro.ProviderStatus.DISABLED;

                                // this.provider_initialized ((T) provider);

                                this.check_provider_status (provider_info);
                            }
                            catch (GLib.Error error) {
                                GLib.warning ("Error while initializing %s: %s",
                                              provider.get_type ().name (),
                                              error.message);
                                provider_info.status = Pomodoro.ProviderStatus.NOT_INITIALIZED;
                            }
                        });
                }

                if (provider_info.status == Pomodoro.ProviderStatus.DISABLED &&
                    provider_info.selected &&
                    provider.available)
                {
                    provider_info.status = Pomodoro.ProviderStatus.ENABLING;
                    provider_info.cancellable = new GLib.Cancellable ();
                    provider.enable.begin (
                        provider_info.cancellable,
                        (obj, res) => {
                            try {
                                provider.enable.end (res);
                                provider_info.status = Pomodoro.ProviderStatus.ENABLED;
                                provider.enabled = true;
                                this.check_provider_status (provider_info);
                            }
                            catch (GLib.Error error) {
                                GLib.warning ("Error while enabling %s: %s",
                                              provider.get_type ().name (),
                                              error.message);
                                provider_info.status = Pomodoro.ProviderStatus.DISABLED;
                            }
                        });
                }

                if (provider_info.status == Pomodoro.ProviderStatus.ENABLED && !provider_info.selected)
                {
                    provider_info.status = Pomodoro.ProviderStatus.DISABLING;
                    provider.enabled = false;
                    provider.disable.begin (
                        (obj, res) => {
                            try {
                                provider.disable.end (res);
                                provider_info.status = Pomodoro.ProviderStatus.DISABLED;

                                this.check_provider_status (provider_info);
                            }
                            catch (GLib.Error error) {
                                GLib.warning ("Error while disabling %s: %s",
                                              provider.get_type ().name (),
                                              error.message);
                                provider_info.status = Pomodoro.ProviderStatus.DISABLED;
                            }
                        });
                }
            }
            else if (provider_info.status == Pomodoro.ProviderStatus.ENABLED)
            {
                // Ensure provider is disabled and uninitialized before destroying.
                // We try to disable provider even if it's unavailable.

                provider_info.status = Pomodoro.ProviderStatus.DISABLING;
                provider.enabled = false;
                provider.disable.begin (
                    (obj, res) => {
                        try {
                            provider.disable.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while disabling %s: %s",
                                          provider.get_type ().name (),
                                          error.message);
                        }

                        // We always mark it here as DISABLED, so that it will be deallocated when destroying.
                        provider_info.status = Pomodoro.ProviderStatus.DISABLED;

                        this.check_provider_status (provider_info);
                    });
            }
            else if (provider_info.status == Pomodoro.ProviderStatus.DISABLED && provider_info.destroying)
            {
                provider_info.status = Pomodoro.ProviderStatus.UNINITIALIZING;
                provider.uninitialize.begin (
                    (obj, res) => {
                        try {
                            provider.uninitialize.end (res);
                        }
                        catch (GLib.Error error) {
                            GLib.warning ("Error while uninitializing %s: %s",
                                          provider.get_type ().name (),
                                          error.message);
                        }

                        // We always mark it here as NOT_INITIALIZED when destroying.
                        provider_info.status = Pomodoro.ProviderStatus.NOT_INITIALIZED;

                        // this.provider_uninitialized ((T) provider);
                    });
            }
        }

        private static int compare (Pomodoro.ProviderInfo provider_info,
                                    int64                 provider_timeout,
                                    Pomodoro.ProviderInfo other_info,
                                    int64                 other_timeout)
        {
            var provider_available = provider_info.instance.available_set
                    ? provider_info.instance.available
                    : provider_timeout < AVAILABILITY_TIMEOUT;
            var other_available = other_info.instance.available_set
                    ? other_info.instance.available
                    : other_timeout < AVAILABILITY_TIMEOUT;

            if (provider_available != other_available) {
                return provider_available ? -1 : 1;
            }

            if (provider_info.priority != other_info.priority) {
                return provider_info.priority > other_info.priority ? -1 : 1;
            }

            if (provider_info.selected != other_info.selected) {
                return provider_info.selected ? -1 : 1;
            }

            return 0;
        }

        private void get_preferred_provider_info (out unowned Pomodoro.ProviderInfo? preferred_provider_info,
                                                  out int64                          preferred_provider_timeout)
        {
            unowned Pomodoro.ProviderInfo? tmp_preferred_provider_info = null;
            int64                          tmp_preferred_provider_timeout = 0;
            int64                          monotonic_time = Pomodoro.Timestamp.UNDEFINED;

            this.providers.@foreach (
                (provider_info) => {
                    var provider_timeout = provider_info.get_availability_timeout (ref monotonic_time);

                    if (tmp_preferred_provider_info == null)
                    {
                        tmp_preferred_provider_info = provider_info;
                        tmp_preferred_provider_timeout = provider_timeout;
                    }
                    else {
                        var comparison_result = compare (tmp_preferred_provider_info,
                                                         tmp_preferred_provider_timeout,
                                                         provider_info,
                                                         provider_timeout);
                        if (comparison_result > 0) {
                            tmp_preferred_provider_info = provider_info;
                            tmp_preferred_provider_timeout = provider_timeout;
                        }
                    }
                });

            preferred_provider_info = tmp_preferred_provider_info;
            preferred_provider_timeout = tmp_preferred_provider_timeout;
        }

        /**
         * Find best provider, preferably available with highest priority.
         */
        private void update_selection_one ()
        {
            unowned Pomodoro.ProviderInfo? preferred_provider_info = null;
            int64                          preferred_provider_timeout = 0;

            this.get_preferred_provider_info (out preferred_provider_info,
                                              out preferred_provider_timeout);

            if (preferred_provider_timeout > 0)
            {
                this.update_selection_timeout_id = GLib.Timeout.add (
                        Pomodoro.Timestamp.to_milliseconds_uint (preferred_provider_timeout +
                                                                 AVAILABILITY_TIMEOUT_TOLERANCE),
                        this.on_update_selection_timeout);
                GLib.Source.set_name_by_id (this.update_selection_timeout_id,
                                            "Pomodoro.ProviderSet.on_update_selection_timeout");
                return;
            }

            this.providers.@foreach (
                (provider_info) => {
                    var selected = provider_info == preferred_provider_info;

                    if (provider_info.selected != selected)
                    {
                        provider_info.selected = selected;

                        if (selected) {
                            this.provider_selected ((T) provider_info.instance);
                        }
                        else {
                            this.provider_unselected ((T) provider_info.instance);
                        }

                        this.check_provider_status (provider_info);
                    }
                });
        }

        /**
         * Disable all providers.
         */
        private void update_selection_none ()
        {
            this.providers.@foreach (
                (provider_info) => {
                    if (provider_info.selected) {
                        provider_info.selected = false;
                        this.provider_unselected ((T) provider_info.instance);
                        this.check_provider_status (provider_info);
                    }
                });
        }

        /**
         * Try enabling all providers.
         */
        private void update_selection_all ()
        {
            this.providers.@foreach (
                (provider_info) => {
                    if (!provider_info.selected) {
                        provider_info.selected = true;
                        this.provider_selected ((T) provider_info.instance);
                        this.check_provider_status (provider_info);
                    }
                });
        }

        private void update_selection ()
        {
            if (this.updating_selection) {
                this.selection_invalid = true;
                return;
            }

            this.updating_selection = true;
            this.selection_invalid = false;

            if (this.update_selection_timeout_id != 0) {
                GLib.Source.remove (this.update_selection_timeout_id);
                this.update_selection_timeout_id = 0;
            }

            switch (this._selection_mode)
            {
                case Pomodoro.SelectionMode.NONE:
                    this.update_selection_none ();
                    break;

                case Pomodoro.SelectionMode.ONE:
                    this.update_selection_one ();
                    break;

                case Pomodoro.SelectionMode.ALL:
                    this.update_selection_all ();
                    break;

                default:
                    assert_not_reached ();
            }

            this.updating_selection = false;

            if (this.selection_invalid) {
                this.update_selection ();
            }
        }

        private unowned Pomodoro.ProviderInfo? lookup_info (Pomodoro.Provider instance)
        {
            unowned Pomodoro.ProviderInfo provider_info = null;

            this.providers.@foreach (
                (_provider_info) => {
                    if (_provider_info.instance == instance) {
                        provider_info = _provider_info;
                    }
                });

            return provider_info;
        }

        private bool on_update_selection_timeout ()
        {
            this.update_selection_timeout_id = 0;
            this.update_selection ();

            return GLib.Source.REMOVE;
        }

        private void on_provider_notify_available (GLib.Object    object,
                                                   GLib.ParamSpec pspec)
        {
            var provider = (Pomodoro.Provider) object;
            var provider_info = this.lookup_info (provider);

            assert (provider_info != null);

            if (provider_info.selected && provider.available) {
                this.check_provider_status (provider_info);
            }
            else {
                this.update_selection ();
            }
        }

        private void on_provider_notify_enabled (GLib.Object    object,
                                                 GLib.ParamSpec pspec)
        {
            var provider = (Pomodoro.Provider) object;

            if (provider.enabled) {
                this.provider_enabled ((T) provider);
            }
            else {
                this.provider_disabled ((T) provider);
            }
        }

        private void destroy_info (Pomodoro.ProviderInfo provider_info)
        {
            provider_info.instance.notify["available"].disconnect (this.on_provider_notify_available);
            provider_info.instance.notify["enabled"].connect (this.on_provider_notify_enabled);

            provider_info.destroying = true;

            if (provider_info.cancellable != null) {
                provider_info.cancellable.cancel ();
                provider_info.cancellable = null;
            }

            this.check_provider_status (provider_info);
        }

        public void add (T                 provider,
                         Pomodoro.Priority priority = Pomodoro.Priority.DEFAULT)
        {
            var instance = provider as Pomodoro.Provider;

            assert (instance != null);

            var existing_provider_info = this.lookup_info (instance);

            if (existing_provider_info != null) {
                existing_provider_info.priority = priority;
            }
            else {
                var provider_info = new Pomodoro.ProviderInfo (instance, priority);

                if (this.providers.add (provider_info)) {
                    provider_info.instance.notify["available"].connect (this.on_provider_notify_available);
                    provider_info.instance.notify["enabled"].connect (this.on_provider_notify_enabled);
                }
            }

            this.update_selection ();
        }

        public void remove (T provider)
        {
            var instance = provider as Pomodoro.Provider;

            assert (instance != null);

            var provider_info = this.lookup_info (instance);

            if (provider_info == null || !this.providers.remove (provider_info)) {
                return;
            }

            this.destroy_info (provider_info);

            if (provider_info.selected) {
                this.update_selection ();
            }
        }

        public void remove_all ()
        {
            if (this.update_selection_timeout_id != 0) {
                GLib.Source.remove (this.update_selection_timeout_id);
                this.update_selection_timeout_id = 0;
            }

            this.providers.@foreach (
                (provider_info) => {
                    this.destroy_info (provider_info);
                });
            this.providers.remove_all ();
        }

        public void enable_one ()
        {
            if (this._selection_mode != Pomodoro.SelectionMode.ONE)
            {
                this._selection_mode = Pomodoro.SelectionMode.ONE;

                this.update_selection ();
            }
        }

        // public void enable_all ()
        // {
        //     if (this._selection_mode != Pomodoro.SelectionMode.ALL)
        //     {
        //         this._selection_mode = Pomodoro.SelectionMode.ALL;
        //
        //         this.update_selection ();
        //     }
        // }

        // public void disable_all ()
        // {
        //     if (this._selection_mode != Pomodoro.SelectionMode.NONE)
        //     {
        //         this._selection_mode = Pomodoro.SelectionMode.NONE;
        //
        //         this.update_selection ();
        //     }
        // }

        public void @foreach (GLib.Func<T> func)
        {
            this.providers.@foreach (
                (provider_info) => {
                    func ((T) provider_info.instance);
                });
        }

        // public void foreach_selected (GLib.Func<T> func)
        // {
        //     this.providers.@foreach (
        //         (provider_info) => {
        //             if (provider_info.selected) {
        //                 func ((T) provider_info.instance);
        //             }
        //         });
        // }

        // public void foreach_available (GLib.Func<T> func)
        // {
        //     this.providers.@foreach (
        //         (provider_info) => {
        //             if (provider_info.instance.available) {
        //                 func ((T) provider_info.instance);
        //             }
        //         });
        // }

        public void foreach_enabled (GLib.Func<T> func)
        {
            this.providers.@foreach (
                (provider_info) => {
                    if (provider_info.instance.enabled) {
                        func ((T) provider_info.instance);
                    }
                });
        }

        internal signal void provider_selected (T provider);

        internal signal void provider_unselected (T provider);

        // public signal void provider_initialized (T provider);

        // public signal void provider_uninitialized (T provider);

        public signal void provider_enabled (T provider);

        public signal void provider_disabled (T provider);

        public override void dispose ()
        {
            if (this.providers != null)
            {
                this.remove_all ();

                this.providers = null;
            }

            base.dispose ();
        }
    }
}
