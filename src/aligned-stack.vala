namespace Pomodoro
{
    internal inline Gtk.Orientation opposite_orientation (Gtk.Orientation orientation)
    {
        return orientation == Gtk.Orientation.HORIZONTAL
            ? Gtk.Orientation.VERTICAL
            : Gtk.Orientation.HORIZONTAL;
    }

    /**
     * Container for transitioning between widgets of varying sizes.
     *
     * `Gtk.Stack` transitions between children interpolating size with origin at the center.
     * Here we can specify how children are aligned. For instance top-left alignment is used for shrinking
     * window.
     */
    // TODO: rename as Reducer / Condenser / Shrinker / Revealer / ModeSwitch?
    public class AlignedStack : Gtk.Widget, Gtk.Buildable
    {
        private class ChildInfo
        {
            public Gtk.Widget widget;
            public weak Gtk.Widget? last_focus = null;

            // public GtkATContext *at_context;

            public int last_width = -1;
            public int last_height = -1;
            // var minimum_size = Gtk.Requisition ();
            // var natural_size = Gtk.Requisition ();

            // public bool visible = false;
            // public uint needs_attention : 1;
            // public uint use_underline   : 1;

            public ulong notify_visible_id = 0;

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
                // assert (value.parent == this);

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

        public int visible_child_index {  // TODO: remove
            get {
                return this.children.index (this._visible_child);
            }
            set {
                var child_info = this.children.nth_data (value);

                this.visible_child = child_info != null ? child_info.widget : null;
            }
        }

        // The animation duration, in milliseconds.
        public uint transition_duration { get; set construct; default = 300; }

        // Whether to force window to animate its size
        public bool interpolate_window_size { get; set construct; default = false; }  // TODO: apply it


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
            if (this.interpolate_window_size)
            {
                var window = this.get_root () as Gtk.Window;

                if (window != null) {
                    window.set_default_size (-1, -1);
                }
            }
        }

        private void stop_transition ()
        {
            if (this.transition_animation != null) {
                this.transition_animation.pause ();
                this.transition_animation = null;
            }

            // Unset last_visible_child. It was kept for the pupuse of transition.
            if (this.last_visible_child != null) {
                this.last_visible_child.widget.set_child_visible (false);
                this.last_visible_child = null;
            }

            // Always calculate fresh size for the visible child.
            this._visible_child.last_width = -1;
            this._visible_child.last_height = -1;

            // if (contains_focus)  // TODO: does not seem to work
            // {
            //     if (this._visible_child.last_focus != null &&
            //         this._visible_child.last_focus.visible)
            //     {
            //         this._visible_child.last_focus.grab_focus ();  // TODO: iterate parents, grab focus for first visible parent
            //     }
            //     else {
            //         this._visible_child.widget.child_focus (Gtk.DirectionType.TAB_FORWARD);
            //     }
            // }
        }

        private void start_transition (uint transition_duration)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;

            if (last_visible_child == null || transition_duration == 0)
            {
                this.stop_transition ();
                this.maybe_clear_window_default_size ();
                this.queue_resize ();
                return;
            }

            // Store size of current child and estimate size of next one.
            last_visible_child.last_width = last_visible_child.widget.get_width ();
            last_visible_child.last_height = last_visible_child.widget.get_height ();

            // TODO: restore previous size
            // if (visible_child.last_width >= 0 &&
            //     visible_child.last_height >= 0)
            // {
            //     visible_child.last_width = visible_child.last_width;
            //     visible_child.last_height = visible_child.last_height;
            // }
            // else {
            var natural_size = Gtk.Requisition ();
            visible_child.widget.get_preferred_size (null, out natural_size);
            visible_child.last_width = natural_size.width;
            visible_child.last_height = natural_size.height;
            // }

            // Setup transition
            if (this.transition_animation != null) {
                this.transition_animation.pause ();
                this.transition_animation = null;
            }

            var animation_target = new Adw.CallbackAnimationTarget ((value) => {
                this.maybe_clear_window_default_size ();
                this.queue_resize ();
            });

            var animation = new Adw.TimedAnimation (this, 0.0, 1.0, transition_duration, animation_target);
            animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            animation.done.connect (() => {
                this.stop_transition ();
            });

            this.transition_animation = animation;

            animation.play ();
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

                if (contains_focus)  // TODO: does not seem to work, perhaps because toggle button is inside popover
                {
                    if (child_info.last_focus != null &&
                        child_info.last_focus.visible)
                    {
                        child_info.last_focus.grab_focus ();  // TODO: iterate parents, grab focus for first visible parent?
                    }
                    else {
                        child_info.widget.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    }
                }
            }

            this._visible_child = child_info;
            this.queue_resize ();
            this.notify_property ("visible-child");

            this.start_transition (transition_duration);
        }

        // TODO: call this.animation.skip () if widget gets unmapped
        // if (!gtk_widget_get_mapped (widget))
        //     gtk_progress_tracker_finish (&priv->tracker);

        // TODO: handle child changes

        // TODO: handle child.notify["visibility"]

        private void on_notify_visible (GLib.Object object,
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

            this.stop_transition ();

            // TODO
            // gtk_accessible_update_state (GTK_ACCESSIBLE (child_info),
            //                            GTK_ACCESSIBLE_STATE_HIDDEN, !visible,
            //                            -1);
        }

        private void add_child_internal (Gtk.Widget child)
        {
            var child_info = new ChildInfo (child);

            this.children.append (child_info);

            child.set_child_visible (false);
            child.set_parent (this);

            child_info.notify_visible_id = child_info.widget.notify["visible"].connect (this.on_notify_visible);

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

        // public override void compute_expand_internal (out bool hexpand,
        //                                               out bool vexpand)
        // {
        //     hexpand = false;
        //     vexpand = false;
        // }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return this.transition_animation != null
                ? Gtk.SizeRequestMode.CONSTANT_SIZE
                : base.get_request_mode ();
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

            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (visible_child != null)
            {
                // Use cached size during animation. Also, dont compute minium size.  # TODO: should we interpolate it too?
                if (visible_child.last_width != -1 &&
                    visible_child.last_height != -1 &&
                    transition_progress < 1.0)
                {
                    minimum = natural = orientation == Gtk.Orientation.HORIZONTAL
                        ? visible_child.last_width
                        : visible_child.last_height;
                }
                else {
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
                }
            }

            if (last_visible_child != null &&
                last_visible_child.last_width >= 0 &&
                last_visible_child.last_height >= 0 &&
                transition_progress < 1.0)
            {
                var last_size = orientation == Gtk.Orientation.HORIZONTAL
                    ? last_visible_child.last_width
                    : last_visible_child.last_height;

                // minimum = (int) GLib.Math.round (Adw.lerp ((double) last_size, (double) minimum, transition_progress));
                minimum = natural = (int) GLib.Math.round (Adw.lerp ((double) last_size, (double) natural, transition_progress));
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

            // TODO: when revealing `visible_child` from collapsed state to full, widget adjust to window size - it should be fixed size
            // TODO: we should prioritize natural size over minimal
            // TODO: roles of bigger widget and smaller reverse: once its visible_child, once last_visible_child. Bigger widget should always be beneath

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

                if (visible_child.last_width >= 0 &&
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

                    // TODO: handle other halign / valign types

                    // if (child_allocation.width > width)
                    // {
                    //     var halign = visible_child.halign;
                    //
                    //     if (halign == Gtk.Align.CENTER || halign == Gtk.Align.FILL)
                    //         child_allocation.x = (width - child_allocation.width) / 2;
                    //     else if (halign == GTK_ALIGN_END)
                    //         child_allocation.x = (width - child_allocation.width);
                    // }

                    // if (child_allocation.height > height)
                    // {
                    //     GtkAlign valign = gtk_widget_get_valign (priv->visible_child->widget);
                    //
                    //   if (valign == GTK_ALIGN_CENTER || valign == GTK_ALIGN_FILL)
                    //     child_allocation.y = (height - child_allocation.height) / 2;
                    //   else if (valign == GTK_ALIGN_END)
                    //     child_allocation.y = (height - child_allocation.height);
                    // }
                }

                visible_child.widget.allocate_size (visible_child_allocation, -1);
            }
        }

        private void snapshot_crossfade (Gtk.Snapshot snapshot)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;
            var transition_progress = this.get_transition_progress ();

            if (last_visible_child != null &&
                last_visible_child.widget != null &&
                last_visible_child.widget.visible)
            {
                snapshot.save ();
                this.snapshot_child (last_visible_child.widget, snapshot);
                snapshot.restore ();
            }

            if (visible_child != null &&
                visible_child.widget != null &&
                visible_child.widget.visible)
            {
                snapshot.save ();
                snapshot.push_opacity (Math.pow (transition_progress, 1.5));
                this.snapshot_child (visible_child.widget, snapshot);
                snapshot.pop ();
                snapshot.restore ();
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;
            var bounds = Graphene.Rect ();
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
                return;
            }
        }

        // TODO: sometimes window is not reactive to tab navigation,
        public override bool focus (Gtk.DirectionType direction)
        {
            if (this._visible_child != null &&
                this._visible_child.widget != null &&
                this._visible_child.widget.visible)
            {
                return this._visible_child.widget.focus (direction);
            }

            return false;
        }

        public override void dispose ()
        {
            unowned Gtk.Widget? child;

            while ((child = this.get_first_child ()) != null)
            {
                this.remove_child_internal (child, true);
            }

            base.dispose ();
        }


/*
static void
gtk_stack_size_allocate (GtkWidget *widget,
                         int        width,
                         int        height,
                         int        baseline)
{
  GtkStack *stack = GTK_STACK (widget);
  GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
  GtkAllocation child_allocation;

  if (priv->last_visible_child)
    {
      int child_width, child_height;
      int min, nat;

      gtk_widget_measure (priv->last_visible_child->widget, GTK_ORIENTATION_HORIZONTAL,
                          -1,
                          &min, &nat, NULL, NULL);
      child_width = MAX (min, width);
      gtk_widget_measure (priv->last_visible_child->widget, GTK_ORIENTATION_VERTICAL,
                          child_width,
                          &min, &nat, NULL, NULL);
      child_height = MAX (min, height);

      gtk_widget_size_allocate (priv->last_visible_child->widget,
                                &(GtkAllocation) { 0, 0, child_width, child_height }, -1);
    }

  child_allocation.x = get_bin_window_x (stack);
  child_allocation.y = get_bin_window_y (stack);
  child_allocation.width = width;
  child_allocation.height = height;

  if (priv->visible_child)
    {
      int min_width;
      int min_height;

      gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_HORIZONTAL,
                          height, &min_width, NULL, NULL, NULL);
      child_allocation.width = MAX (child_allocation.width, min_width);

      gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_VERTICAL,
                          child_allocation.width, &min_height, NULL, NULL, NULL);
      child_allocation.height = MAX (child_allocation.height, min_height);

      if (child_allocation.width > width)
        {
          GtkAlign halign = gtk_widget_get_halign (priv->visible_child->widget);

          if (halign == GTK_ALIGN_CENTER || halign == GTK_ALIGN_FILL)
            child_allocation.x = (width - child_allocation.width) / 2;
          else if (halign == GTK_ALIGN_END)
            child_allocation.x = (width - child_allocation.width);
        }

      if (child_allocation.height > height)
        {
          GtkAlign valign = gtk_widget_get_valign (priv->visible_child->widget);

          if (valign == GTK_ALIGN_CENTER || valign == GTK_ALIGN_FILL)
            child_allocation.y = (height - child_allocation.height) / 2;
          else if (valign == GTK_ALIGN_END)
            child_allocation.y = (height - child_allocation.height);
        }

      gtk_widget_size_allocate (priv->visible_child->widget, &child_allocation, -1);
    }
}

#define LERP(a, b, t) ((a) + (((b) - (a)) * (1.0 - (t))))
static void
gtk_stack_measure (GtkWidget      *widget,
                   GtkOrientation  orientation,
                   int             for_size,
                   int            *minimum,
                   int            *natural,
                   int            *minimum_baseline,
                   int            *natural_baseline)
{
  GtkStack *stack = GTK_STACK (widget);
  GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
  GtkStackPage *child_info;
  GtkWidget *child;
  int child_min, child_nat;
  GList *l;

  *minimum = 0;
  *natural = 0;

  for (l = priv->children; l != NULL; l = l->next)
    {
      child_info = l->data;
      child = child_info->widget;

      if (!priv->homogeneous[orientation] &&
          priv->visible_child != child_info)
        continue;

      if (gtk_widget_get_visible (child))
        {
          if (!priv->homogeneous[OPPOSITE_ORIENTATION(orientation)] && priv->visible_child != child_info)
            {
              int min_for_size;

              gtk_widget_measure (child, OPPOSITE_ORIENTATION (orientation), -1, &min_for_size, NULL, NULL, NULL);

              gtk_widget_measure (child, orientation, MAX (min_for_size, for_size), &child_min, &child_nat, NULL, NULL);
            }
          else
            gtk_widget_measure (child, orientation, for_size, &child_min, &child_nat, NULL, NULL);

          *minimum = MAX (*minimum, child_min);
          *natural = MAX (*natural, child_nat);
        }
    }

  if (priv->last_visible_child != NULL && !priv->homogeneous[orientation])
    {
      double t = priv->interpolate_size ? gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE) : 1.0;
      int last_size;

      if (orientation == GTK_ORIENTATION_HORIZONTAL)
        last_size = priv->last_visible_widget_width;
      else
        last_size = priv->last_visible_widget_height;

      *minimum = LERP (*minimum, last_size, t);
      *natural = LERP (*natural, last_size, t);
    }
}
*/

    }


/*
        public void open ()
        {
            if (this.state == Pomodoro.RevealerState.OPENING || this.state == Pomodoro.RevealerState.OPENED) {
                return;
            }

            var value_from = 0.0;
            var value_to = 1.0;

            if (this.animation != null) {  // && this.animation.state == Adw.AnimationState.PLAYING) {
                value_from = this.animation.value;

                this.animation.pause ();
            }

            var animation_duration = this.transition_duration;
            var animation_target = new Adw.CallbackAnimationTarget ((value) => {
                this.queue_resize ();
            });
            var animation = new Adw.TimedAnimation (this, value_from, value_to, animation_duration, animation_target);
            animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            animation.done.connect (() => {
                this.state = Pomodoro.RevealerState.OPENED;
                this.animation = null;

                // this.notify_property ("child-revealed");
            });

            this.animation = animation;
            this.state = Pomodoro.RevealerState.OPENING;
            this.update_child_visible ();

            animation.play ();
        }

        public void close ()
        {
            if (this.state == Pomodoro.RevealerState.CLOSING || this.state == Pomodoro.RevealerState.CLOSED) {
                return;
            }

            var value_from = 1.0;
            var value_to = 0.0;

            if (this.animation != null) {  // && this.animation.state == Adw.AnimationState.PLAYING) {
                value_from = this.animation.value;

                this.animation.pause ();
            }

            var animation_duration = this.transition_duration;
            var animation_target = new Adw.CallbackAnimationTarget ((value) => {
                this.queue_resize ();
            });
            var animation = new Adw.TimedAnimation (this, value_from, value_to, animation_duration, animation_target);
            animation.easing = Adw.Easing.EASE_IN_OUT_CUBIC;
            animation.done.connect (() => {
                this.animation = null;
                this.state = Pomodoro.RevealerState.CLOSED;
                this.update_child_visible ();
            });

            this.animation = animation;
            this.state = Pomodoro.RevealerState.CLOSING;

            animation.play ();
        }
*/




}
