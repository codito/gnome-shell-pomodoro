namespace Pomodoro
{
    internal inline Gtk.Orientation opposite_orientation (Gtk.Orientation orientation)
    {
        return orientation == Gtk.Orientation.HORIZONTAL
            ? Gtk.Orientation.VERTICAL
            : Gtk.Orientation.HORIZONTAL;
    }

    // TODO: clear last size on style/theme change

    /**
     * Container for transitioning between widgets of varying sizes.
     *
     * The purpuse is to swap widgets of varying complexity or just diferent variants. Default transition is tailored
     * towards reducing window contents - origin of the transition is at top left corner.
     */
    public class Reducer : Gtk.Widget, Gtk.Buildable
    {
        private class ChildInfo
        {
            public Gtk.Widget       widget;
            public weak Gtk.Widget? last_focus = null;
            public int              last_width = -1;
            public int              last_height = -1;
            public ulong            notify_visible_id = 0;
            public ulong            unmap_id = 0;
            // public Gtk.ATContext at_context;

            public ChildInfo (Gtk.Widget widget)
            {
                this.widget = widget;
            }
        }

        public unowned Gtk.Widget? visible_child {
            get {
                return this._visible_child != null
                    ? this._visible_child.widget
                    : null;
            }
            set {
                var child_info = this.find_child_info_for_widget (value);
                if (child_info == null)
                {
                    warning ("Given child of type '%s' not found in PomodoroAlignedStack",
                             value.get_type ().name ());
                    return;
                }

                if (child_info.widget.visible) {
                    this.set_visible_child_internal (child_info, this.transition_duration);
                }
            }
        }

        // The animation duration, in milliseconds.
        public uint transition_duration { get; set construct; default = 500; }

        // Whether to force window to animate its size
        public bool interpolate_window_size { get; set construct; default = false; }

        private GLib.List<ChildInfo> children;
        private Adw.Animation?       transition_animation;
        private unowned ChildInfo?   _visible_child;
        private unowned ChildInfo?   last_visible_child;


        private unowned ChildInfo? find_child_info_for_widget (Gtk.Widget child)
        {
            unowned GLib.List<ChildInfo> link;
            unowned ChildInfo info;

            for (link = this.children; link != null; link = link.next)
            {
                info = link.data;
                if (info.widget == child) {
                    return info;
                }
            }

            return null;
        }

        private double get_transition_progress ()
        {
            if (this.transition_animation != null) {
                return this.transition_animation.value;
            }

            if (this._visible_child != null && this.last_visible_child == null) {
                return 1.0;
            }

            return 0.0;
        }

        /**
         * In Gtk4, Window insists on preserving its remembered size. We need to invalidate it.
         * See `gtk_window_compute_default_size`.
         */
        private void maybe_clear_window_default_size ()
        {
            if (!this.interpolate_window_size) {
                return;
            }

            var window = this.get_root () as Gtk.Window;

            if (window != null &&
                window.default_width >= 0 &&
                window.default_height >= 0)
            {
                window.set_default_size (-1, -1);
            }
        }

        private void on_transition_animation_done (Adw.Animation animation)
        {
            if (this.transition_animation != animation) {
                return;
            }

            this.transition_animation.pause ();
            this.transition_animation = null;

            // Unset last_visible_child. It was kept for the pupuse of transition.
            if (this.last_visible_child != null) {
                this.last_visible_child.widget.set_child_visible (false);
                this.last_visible_child = null;
            }

            this.transition_end ();

            this.queue_resize ();
        }

        private void start_transition (uint transition_duration)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;
            var natural_size = Gtk.Requisition ();

            // Store size of current child and estimate size of next one.
            if (last_visible_child != null)
            {
                last_visible_child.last_width = last_visible_child.widget.get_width ();
                last_visible_child.last_height = last_visible_child.widget.get_height ();
            }

            // See if transition is needed.
            if (this.transition_animation != null) {
                this.transition_animation.pause ();
            }

            // Setup transition
            var animation_target = new Adw.CallbackAnimationTarget ((value) => {
                this.maybe_clear_window_default_size ();
                this.queue_resize ();
            });

            var animation = new Adw.TimedAnimation (this, 0.0, 1.0, transition_duration, animation_target);
            animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            animation.done.connect (() => {
                GLib.Idle.add (() => {
                    this.on_transition_animation_done (animation);

                    return GLib.Source.REMOVE;
                });
            });
            animation.play ();

            this.transition_animation = animation;
            this.transition_begin ();

            this.maybe_clear_window_default_size ();
            this.queue_resize ();
        }

        private void set_visible_child_internal (ChildInfo? child_info,
                                                 uint       transition_duration)
        {
            unowned GLib.List<ChildInfo> link;
            var contains_focus = false;

            // If we are being destroyed, do not bother with transitions
            // and notifications
            if (this.in_destruction ()) {
                return;
            }

            if (child_info == null)
            {
                for (link = this.children; link != null; link = link.next)
                {
                    if (link.data.widget.visible) {
                        child_info = link.data;
                    }
                }
            }

            if (child_info == this._visible_child) {
                return;
            }

            // Store focus for the current child
            if (this.root != null &&
                this._visible_child != null &&
                this._visible_child.widget != null)
            {
                var focus = this.root.get_focus ();

                if (focus != null && focus.is_ancestor (this._visible_child.widget))
                {
                    contains_focus = true;

                    this._visible_child.last_focus = focus;
                }
                else {
                    this._visible_child.last_focus = null;
                }
            }

            if (this.last_visible_child != null) {
                this.last_visible_child.widget.set_child_visible (false);
                this.last_visible_child = null;
            }

            if (this._visible_child != null) {
                this.last_visible_child = this._visible_child;
            }
            else {
                transition_duration = 0;
            }

            if (child_info != null &&
                child_info.widget != null)
            {
                child_info.widget.set_child_visible (true);

                if (contains_focus)
                {
                    if (child_info.last_focus != null) {
                        // FIXME? Restoring focus to Gtk.ModelButton doesnt seem to work
                        // child_info.last_focus.grab_focus ();
                        child_info.widget.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    }
                    else {
                        child_info.widget.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    }
                }
            }

            this._visible_child = child_info;
            this.notify_property ("visible-child");

            this.start_transition (transition_duration);
        }

        private void on_child_notify_visible (GLib.Object    object,
                                              GLib.ParamSpec pspec)
        {
            var child_info = this.find_child_info_for_widget ((Gtk.Widget) object);
            var visible = child_info.widget.visible;

            if (this._visible_child == null && visible) {
                this.set_visible_child_internal (child_info, this.transition_duration);
            }
            else if (this._visible_child == child_info && !visible) {
                this.set_visible_child_internal (null, this.transition_duration);
            }

            if (this.last_visible_child == child_info)
            {
                this.last_visible_child.widget.set_child_visible (false);
                this.last_visible_child = null;
            }

            this.start_transition (0);

            // TODO
            // gtk_accessible_update_state (GTK_ACCESSIBLE (child_info),
            //                            GTK_ACCESSIBLE_STATE_HIDDEN, !visible,
            //                            -1);
        }

        private void on_child_unmap (Gtk.Widget widget)
        {
            if (this.transition_animation != null) {
                this.transition_animation.skip ();
            }
        }

        private void add_child_internal (Gtk.Widget child)
        {
            var child_info = new ChildInfo (child);

            this.children.append (child_info);

            child.set_child_visible (false);
            child.set_parent (this);

            child_info.notify_visible_id = child_info.widget.notify["visible"].connect (this.on_child_notify_visible);
            child_info.unmap_id = child_info.widget.unmap.connect (this.on_child_unmap);

            if (this._visible_child == null && child.visible) {
                this.set_visible_child_internal (child_info, this.transition_duration);
            }

            if (this._visible_child == child_info) {
                this.queue_resize ();
            }
        }

        public new void add_child (Gtk.Builder builder,
                                   GLib.Object object,
                                   string?     type)
        {
            if (object is Gtk.Widget) {
                this.add_child_internal ((Gtk.Widget) object);
            }
            else {
                base.add_child (builder, object, type);
            }
        }

        private void remove_child_internal (Gtk.Widget child,
                                            bool       in_dispose)
        {
            var child_info = this.find_child_info_for_widget (child);

            if (child_info == null) {
                return;
            }

            child.disconnect (child_info.notify_visible_id);
            child.disconnect (child_info.unmap_id);
            child.unparent ();

            var was_visible = false;

            if (this._visible_child == child_info) {
                this._visible_child = null;
                was_visible = child.visible;
            }

            if (this.last_visible_child == child_info) {
                this.last_visible_child = null;
            }

            this.children.remove (child_info);

            if (!in_dispose && was_visible)
            {
                this.queue_resize ();
            }
        }

        public override void compute_expand_internal (out bool hexpand,
                                                      out bool vexpand)
        {
            unowned GLib.List<ChildInfo> link;

            hexpand = false;
            vexpand = false;

            for (link = this.children; link != null; link = link.next)
            {
                if (link.data.widget != null)
                {
                    hexpand |= link.data.widget.hexpand_set && link.data.widget.hexpand;
                    vexpand |= link.data.widget.vexpand_set && link.data.widget.vexpand;
                }
            }
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.CONSTANT_SIZE;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            var visible_child       = this._visible_child;
            var last_visible_child  = this.last_visible_child;
            var transition_progress = this.get_transition_progress ();
            var minimum_for_size    = 0;
            var last_size           = 0;

            var window = this.get_root () as Gtk.Window;
            var interpolating_window_size = (
                this.interpolate_window_size &&
                window != null &&
                window.default_width < 0 &&
                window.default_height < 0
            );

            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (visible_child != null)
            {
                visible_child.widget.measure (opposite_orientation (orientation),
                                              -1,
                                              out minimum_for_size,
                                              null,
                                              null,
                                              null);
                visible_child.widget.measure (orientation,
                                              int.max (minimum_for_size, for_size),
                                              out minimum,
                                              out natural,
                                              null,
                                              null);

                last_size = orientation == Gtk.Orientation.HORIZONTAL
                    ? visible_child.last_width
                    : visible_child.last_height;

                if (last_size >= 0 && (this.transition_animation != null || interpolating_window_size))
                {
                    natural = last_size;
                }
            }

            if (last_visible_child != null &&
                last_visible_child.last_width >= 0 &&
                last_visible_child.last_height >= 0)
            {
                last_size = orientation == Gtk.Orientation.HORIZONTAL
                    ? last_visible_child.last_width
                    : last_visible_child.last_height;

                natural = (int) GLib.Math.round (
                    Adw.lerp ((double) last_size, (double) natural, transition_progress));

                minimum = (int) GLib.Math.round (
                    Adw.lerp ((double) last_size, (double) minimum, transition_progress));
            }

            if (natural < minimum) {
                natural = minimum;
            }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var visible_child      = this._visible_child;
            var last_visible_child = this.last_visible_child;

            if (last_visible_child != null &&
                last_visible_child.widget != null &&
                last_visible_child.widget.visible)
            {
                var last_visible_child_allocation = Gtk.Allocation () {
                    x = 0,
                    y = 0,
                    width = int.max (last_visible_child.last_width, width),
                    height = int.max (last_visible_child.last_height, height)
                };
                last_visible_child.widget.allocate_size (last_visible_child_allocation, -1);
            }

            if (visible_child != null &&
                visible_child.widget != null &&
                visible_child.widget.visible)
            {
                var visible_child_allocation = Gtk.Allocation () {
                    x = 0,
                    y = 0,
                    width = 0,
                    height = 0
                };
                var min_width = 0;
                var min_height = 0;

                if (this.transition_animation != null &&
                    visible_child.last_width >= 0 &&
                    visible_child.last_height >= 0)
                {
                    visible_child_allocation.width = int.max (visible_child.last_width, width);
                    visible_child_allocation.height = int.max (visible_child.last_height, height);
                }
                else {
                    if (visible_child.widget.halign == Gtk.Align.FILL) {
                        visible_child_allocation.width = width;
                    }
                    else {
                        visible_child.widget.measure (Gtk.Orientation.HORIZONTAL,
                                                      height, out min_width, null, null, null);
                        visible_child_allocation.width = int.max (visible_child_allocation.width, min_width);
                    }

                    if (visible_child.widget.valign == Gtk.Align.FILL) {
                        visible_child_allocation.height = height;
                    }
                    else {
                        visible_child.widget.measure (Gtk.Orientation.VERTICAL,
                                                      visible_child_allocation.width, out min_height, null, null, null);
                        visible_child_allocation.height = int.max (visible_child_allocation.height, min_height);
                    }

                    // TODO: handle other halign / valign values
                }

                visible_child.widget.allocate_size (visible_child_allocation, -1);
            }
        }

        private void snapshot_crossfade (Gtk.Snapshot snapshot)
        {
            var visible_child       = this._visible_child;
            var last_visible_child  = this.last_visible_child;
            var transition_progress = this.get_transition_progress ();

            snapshot.save ();

            if (last_visible_child != null &&
                last_visible_child.widget != null &&
                last_visible_child.widget.visible)
            {
                this.snapshot_child (last_visible_child.widget, snapshot);
            }

            if (visible_child != null &&
                visible_child.widget != null &&
                visible_child.widget.visible)
            {
                snapshot.push_opacity (Math.pow (transition_progress, 1.5));
                this.snapshot_child (visible_child.widget, snapshot);
                snapshot.pop ();
            }

            snapshot.restore ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var visible_child      = this._visible_child;
            var last_visible_child = this.last_visible_child;
            var bounds             = Graphene.Rect ();
            bounds.init (
                0,
                0,
                this.get_width (),
                this.get_height ()
            );

            if (last_visible_child != null &&
                last_visible_child.widget != null &&
                last_visible_child.widget.visible)
            {
                snapshot.push_clip (bounds);
                this.snapshot_crossfade (snapshot);
                snapshot.pop ();
                return;
            }

            if (visible_child != null &&
                visible_child.widget != null &&
                visible_child.widget.visible)
            {
                snapshot.push_clip (bounds);
                this.snapshot_child (visible_child.widget, snapshot);
                snapshot.pop ();
            }
        }

        public signal void transition_begin ();

        public signal void transition_end ();

        public override void dispose ()
        {
            unowned Gtk.Widget? child;

            while ((child = this.get_first_child ()) != null)
            {
                this.remove_child_internal (child, true);
            }

            base.dispose ();
        }
    }
}
