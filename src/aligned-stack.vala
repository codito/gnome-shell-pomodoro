namespace Pomodoro
{
    /**
     * Container for transitioning between widgets of varying sizes.
     *
     * `Gtk.Stack` transitions between children interpolating size with origin at the center.
     * Here we can specify how children are aligned. For instance top-left alignment is used for shrinking
     * window.
     */
    public class AlignedStack : Gtk.Widget, Gtk.Buildable
    {
        internal class ChildInfo
        {
            public Gtk.Widget widget;
            public weak Gtk.Widget? last_focus = null;

            // public GtkATContext *at_context;

            // public int last_width = -1;
            // public int last_height = -1;

            // public bool visible = false;
            // public uint needs_attention : 1;
            // public uint use_underline   : 1;

            public ChildInfo (Gtk.Widget widget)
            {
                this.widget = widget;
                // this.last_focus = null;
                // this.visible = false;
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

        // The type of animation used to transition.
        // public Pomodoro.AlignedStackTransitionType transition_type { get; set construct; }

        // public float xorigin { get; set; default=0.5f }
        // public float yorigin { get; set; default=0.5f }

        private unowned ChildInfo? _visible_child;
        private unowned ChildInfo? last_visible_child;
        private GLib.List<ChildInfo> children;

        // Animation between `last_visible_child` and `visible_child`, noted as values 0.0 - 1.0.
        private Adw.Animation? transition_animation;

        // TODO: handle child changes. Call `gtk_widget_queue_resize (GTK_WIDGET (stack))`?

        construct {
            // var model = this.observe_children ();
            // model.items_changed.connect ((position, removed, added) => {
            //     var child = children.get_item (position);
            // });
        }

        // private uint get_n_items (GLib.ListModel model)
        // {
        //     return this.children.length
        // }

        // static unowned Gtk.Widget? get_item (GLib.ListModel model,
        //                                      uint           position)
        // {
        //     return this.children.nth_data (position);
        // }


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

        // private ChildInfo? get_first_visible_child ()
        // {
        //     unowned GLib.List<ChildInfo> link;
        //     unowned ChildInfo child_info;

        //     for (link = this.children; link != null; link = link.next)
        //     {
        //         child_info = link.data;
        //         if (child_info.widget.visible) {
        //             return child_info;
        //         }
        //     }

        //     return null;
        // }

        private void start_transition (uint transition_duration)
        {
            // TODO: setup transition

            if (this.last_visible_child != null) {
                this.last_visible_child.widget.set_child_visible (false);  // TODO: do this after animation
            }
        }

        private void set_visible_child_internal (ChildInfo? child_info,
                                                 uint       transition_duration)
        {
            Gtk.Widget? focus = null;
            var contains_focus = false;

            // If we are being destroyed, do not bother with transitions
            // and notifications
            if (this.in_destruction ()) {
                return;
            }

            if (child_info == null) {
                // child_info = this.get_first_visible_child ();

                unowned GLib.List<ChildInfo> link;
                // unowned ChildInfo child_info;

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

            if (this.root != null) {
                focus = this.root.get_focus ();
            }

            if (focus != null &&
                this._visible_child != null &&
                this._visible_child.widget != null &&
                focus.is_ancestor (this._visible_child.widget))
            {
                contains_focus = true;

                // if (this._visible_child.last_focus != null) {
                //     this._visible_child.last_focus.remove_weak_pointer (G_OBJECT (),
                //                                   (gpointer *)&priv->visible_child->last_focus);
                // }
                this._visible_child.last_focus = focus;

                // g_object_add_weak_pointer (G_OBJECT (priv->visible_child->last_focus),
                //                            (gpointer *)&priv->visible_child->last_focus);
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

            this._visible_child = child_info;

            if (child_info != null)
            {
                this._visible_child.widget.set_child_visible (true);

                if (contains_focus)
                {
                    if (child_info.last_focus != null) {
                        child_info.last_focus.grab_focus ();
                    }
                    else {
                        child_info.widget.child_focus (Gtk.DirectionType.TAB_FORWARD);
                    }
                }

                if (this.transition_animation != null) {
                    this.transition_animation.pause ();
                    this.transition_animation = null;
                }

                // TODO: validate transition?
                // if (child_info == NULL || priv->last_visible_child == NULL)
                // {
                //   transition_type = GTK_STACK_TRANSITION_TYPE_NONE;
                // }
            }

            this.queue_resize ();
            this.notify_property ("visible-child");

            this.start_transition (transition_duration);
        }

        /*
        private void update_child_visible (ChildInfo child_info)
        {
            // var visible_child = this._visible_child;
            // var last_visible_child = this.last_visible_child;
            // var transition_progress = this.get_transition_progress ();
            var visible = child_info.visible && child_info.widget.visible;

            if (visible_child != null && visible_child.widget != null) {
                visible_child.widget.set_child_visible (true);
            }

            if (last_visible_child != null && last_visible_child.widget != null) {
                last_visible_child.widget.set_child_visible (transition_progress < 1.0);
            }

            // TODO
            // gtk_accessible_update_state (GTK_ACCESSIBLE (child_info),
            //                            GTK_ACCESSIBLE_STATE_HIDDEN, !visible,
            //                            -1);
        }
        */

        // TODO: call this.animation.skip () if widget gets unmapped
        // if (!gtk_widget_get_mapped (widget))
        //     gtk_progress_tracker_finish (&priv->tracker);

        // TODO: handle child changes

        // TODO: handle child.notify["visibility"]

        private void on_notify_visible (GLib.Object object,
                                        GLib.ParamSpec pspec)
        {
            var child_info = this.find_child_info_for_widget ((Gtk.Widget) object);
            // var visible = child_info.visible && child_info.widget.visible;
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

            // TODO: abort animation, not necessarily here

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

            // TODO
            // child_info.notify_visible_id = child_info.widget.notify["visible"].connect (this.on_notify_visible);

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

            // unowned GLib.List<Gtk.Widget> link = this.children.find (child);

            if (child_info == null) {
                return;
            }

            // g_signal_handlers_disconnect_by_func (child,
            //                                     stack_child_visibility_notify_cb,
            //                                     stack);

            var was_visible = child.visible;

            if (this._visible_child == child_info) {
                this._visible_child = null;
            }

            if (this.last_visible_child == child_info) {
                this.last_visible_child = null;
            }

            child.unparent ();

            this.children.remove (child_info);

            // g_object_unref (child_info);

            if (!in_dispose &&
                // (priv->homogeneous[GTK_ORIENTATION_HORIZONTAL] || priv->homogeneous[GTK_ORIENTATION_VERTICAL]) &&  // TODO
                was_visible)
            {
                this.queue_resize ();
            }
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



        public override void compute_expand_internal (out bool hexpand,
                                                      out bool vexpand)
        {
            hexpand = false;
            vexpand = false;
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
            unowned GLib.List<Gtk.Widget> link;
            unowned Gtk.Widget? child;
            var child_minimum = 0;
            var child_natural = 0;
            // var child_minimum_baseline = 0;
            // var child_natural_baseline = 0;
            // var dummy = 0;
            // var expand = false;

            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            if (this._visible_child != null)
            {
                // switch (orientation)
                // {
                //     case Gtk.Orientation.HORIZONTAL:
                //         expand = this._visible_child.hexpand_set && this._visible_child.hexpand;
                //         break;

                //     case Gtk.Orientation.VERTICAL:
                //         expand = this._visible_child.vexpand_set && this._visible_child.vexpand;
                //         break;

                //     default:
                //         break;
                // }

                this._visible_child.widget.measure (orientation,
                                                    for_size,
                                                    out minimum,
                                                    out natural,
                                                    null,
                                                    null);
            }

            if (natural < minimum) {
                natural = minimum;
            }

            // if (natural_baseline < minimum_baseline) {
            //     natural_baseline = minimum_baseline;
            // }

            // TODO: remove
            if (this._visible_child is Adw.HeaderBar)
            {
                if (orientation == Gtk.Orientation.HORIZONTAL) {
                    minimum = 200;
                    natural = 400;
                }
                else {
                    minimum = 42;
                    natural = 42;
                }
            }

            // Calculate size of non-visible child
            // if (!priv->homogeneous[OPPOSITE_ORIENTATION(orientation)] && priv->visible_child != child_info)
            // {
            //      int min_for_size;
            //      gtk_widget_measure (child, OPPOSITE_ORIENTATION (orientation), -1, &min_for_size, NULL, NULL, NULL);
            //      gtk_widget_measure (child, orientation, MAX (min_for_size, for_size), &child_min, &child_nat, NULL, NULL);
            // }

            // warning ("### measure %s %d: %d", (orientation == Gtk.Orientation.HORIZONTAL ? "H" : "V"), for_size, natural);

              // TODO: animate size here

              // var t = this.get_transition_progress ();
              // int last_size;
              //
              // if (orientation == GTK_ORIENTATION_HORIZONTAL)
              //   last_size = priv->last_visible_widget_width;
              // else
              //   last_size = priv->last_visible_widget_height;
              //
              // *minimum = LERP (*minimum, last_size, t);
              // *natural = LERP (*natural, last_size, t);
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            // warning ("### size_allocate %dx%d", width, height);

            var visible_child      = this._visible_child;
            var last_visible_child = this.last_visible_child;

            if (visible_child != null)
            {
                var min_width = 0;
                var min_height = 0;
                var child_allocation = Gtk.Allocation () {
                    x = 0,
                    y = 0,
                    width = 0,
                    height = 0
                };

                if (visible_child.widget.halign == Gtk.Align.FILL) {
                    child_allocation.width = width;
                }
                else {
                    visible_child.widget.measure (Gtk.Orientation.HORIZONTAL,
                                                  height, out min_width, null, null, null);
                    child_allocation.width = int.max (child_allocation.width, min_width);
                }

                if (visible_child.widget.valign == Gtk.Align.FILL) {
                    child_allocation.height = height;
                }
                else {
                    visible_child.widget.measure (Gtk.Orientation.VERTICAL,
                                                  child_allocation.width, out min_height, null, null, null);
                    child_allocation.height = int.max (child_allocation.height, min_height);
                }

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

                // if (this._visible_child is Adw.HeaderBar)
                // {
                //     child_allocation.width = 400;
                //     child_allocation.height = 42;
                // }

                visible_child.widget.allocate_size (child_allocation, -1);
            }

            // TODO: allocate this.last_visible_child
        }

        private void snapshot_crossfade (Gtk.Snapshot snapshot)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;

            // if (child == null || !child.visible) {
            //     return;
            // }

            var transition_progress = this.get_transition_progress ();
            var width               = this.get_width ();
            var height              = this.get_height ();
            var x                   = 0;  // get_bin_window_x (stack);
            var y                   = 0;  // get_bin_window_y (stack);

            // if (last_visible_child != null)
            // {
            //     if (gtk_widget_get_valign (priv->last_visible_child->widget) == GTK_ALIGN_END &&
            //         priv->last_visible_widget_height > height)
            //         y -= priv->last_visible_widget_height - height;
            //     else if (gtk_widget_get_valign (priv->last_visible_child->widget) == GTK_ALIGN_CENTER)
            //         y -= (priv->last_visible_widget_height - height) / 2;
            // }

            snapshot.save ();
            snapshot.translate (
                Graphene.Point () {
                    x = x,
                    y = y
                });
            this.snapshot_child (visible_child.widget, snapshot);
            snapshot.restore ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;

            if (visible_child != null && visible_child.widget.visible)
            {
                if (last_visible_child != null)
                {
                    var bounds = Graphene.Rect ();
                    bounds.init (
                        0,
                        0,
                        this.get_width (),
                        this.get_height ()
                    );

                    snapshot.push_clip (bounds);
                    this.snapshot_crossfade (snapshot);
                    snapshot.pop ();
                }
                else {
                    this.snapshot_child (visible_child.widget, snapshot);
                }
            }
        }

        // public override bool focus (Gtk.DirectionType direction)
        // {
        //     return this._visible_child != null
        //         ? this._visible_child.focus (direction)
        //         : false;
        // }

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
