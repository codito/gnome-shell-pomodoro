namespace Pomodoro
{


 /*
static int get_bin_window_x (GtkStack *stack)
{
  GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
  int width;
  int x = 0;

  width = gtk_widget_get_width (GTK_WIDGET (stack));

  if (gtk_progress_tracker_get_state (&priv->tracker) != GTK_PROGRESS_STATE_AFTER)
    {
      if (is_left_transition (priv->active_transition_type))
        x = width * (1 - gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE));
      if (is_right_transition (priv->active_transition_type))
        x = -width * (1 - gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE));
    }

  return x;
}

private int get_bin_window_y (GtkStack *stack)
{
  GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
  int height;
  int y = 0;

  height = gtk_widget_get_height (GTK_WIDGET (stack));

  if (gtk_progress_tracker_get_state (&priv->tracker) != GTK_PROGRESS_STATE_AFTER)
    {
      if (is_up_transition (priv->active_transition_type))
        y = height * (1 - gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE));
      if (is_down_transition(priv->active_transition_type))
        y = -height * (1 - gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE));
    }

  return y;
}
*/

    /*
    private enum RevealerState
    {
        OPENED,
        OPENING,
        CLOSING,
        CLOSED
    }


    // TODO: Compactor class
    //
    // Reducer

    public class Revealer : Adw.Bin, Gtk.Buildable
    {
        // Whether the child is revealed and the animation target reached.
        // public bool child_revealed {
        //     get {
        //         return this.state == RevealerState.OPENED;
        //     }
        // }

        // TODO: qhandle child change. Call `gtk_widget_queue_resize (GTK_WIDGET (stack))`?

        private void update_child_visible ()
        {
            var child = this.child;

            if (child == null) {
                return;
            }

            var visible = child.visible && this.state != RevealerState.CLOSED;

            child.set_child_visible (visible);

            // gtk_accessible_update_state (GTK_ACCESSIBLE (child_info),
            //                            GTK_ACCESSIBLE_STATE_HIDDEN, !visible,
            //                            -1);
        }

        // Whether the revealer should reveal the child.
        public bool reveal_child {
            get {
                return this.state == RevealerState.OPENING || this.state == RevealerState.OPENED;
            }
            set construct {
                if (value) {
                    this.open ();
                }
                else {
                    this.close ();
                }
            }
        }

        // The animation duration, in milliseconds.
        public uint transition_duration { get; set construct; default = 300; }

        // The type of animation used to transition.
        // RevealerTransitionType transition_type { get; set construct; }

        // public float xalign { get; set; }
        // public float yalign { get; set; }

        private Pomodoro.RevealerState state = Pomodoro.RevealerState.OPENED;

        private Adw.Animation? animation;
        // private uint child_width;
        // private uint child_width;

        // TODO: call this.animation.skip () if widget gets unmapped
        // if (!gtk_widget_get_mapped (widget))
        //     gtk_progress_tracker_finish (&priv->tracker);

        // TODO: handle child changes

        // TODO: handle this.child.notify["visibility"]

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

            // this.notify_property ("child-revealed");
        }

        public override void compute_expand_internal (out bool hexpand,
                                                      out bool vexpand)
        {
            // var child = this.child;

            // if (this.child != null) {
            //     hexpand = child.compute_expand (Gtk.Orientation.HORIZONTAL);
            //     vexpand = child.compute_expand (Gtk.Orientation.VERTICAL);
            // }
            // else {
            // }

            hexpand = false;
            vexpand = false;
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            var child = this.child;

            return child != null
                ? child.get_request_mode ()
                : Gtk.SizeRequestMode.CONSTANT_SIZE;

            // var child            = this.child;
            // var width_for_height = 0;
            // var height_for_width = 0;
            //
            // if (child != null)
            // {
            //     var mode = child.get_request_mode ();
            //
            //     switch (mode)
            //     {
            //         case Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH:
            //             height_for_width++;
            //             break;
            //         case Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT:
            //             width_for_height++;
            //             break;
            //         case Gtk.SizeRequestMode.CONSTANT_SIZE:
            //         default:
            //             break;
            //     }
            // }
            //
            // if (height_for_width == 0 && !width_for_height == 0) {
            //     return Gtk.SizeRequestMode.CONSTANT_SIZE;
            // }
            // else {
            //     return width_for_height > height_for_width ?
            //         Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT :
            //         Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
            // }
        }

        private double get_progress ()
        {
            return this.animation != null
                ? this.animation.value
                : (this.state == RevealerState.CLOSED ? 0.0 : 1.0);
        }

        private void snapshot_slide (Gtk.Snapshot snapshot)
        {
            var child = this.child;

            // if (child == null || !child.visible) {
            //     return;
            // }

            var progress = this.get_progress ();
            var width  = this.get_width ();
            var height = this.get_height ();
            var x      = 0;  // get_bin_window_x (stack);
            var y      = 0;  // get_bin_window_y (stack);


            // switch ((guint) priv->active_transition_type)
            // {
            //     case GTK_STACK_TRANSITION_TYPE_SLIDE_LEFT:
            //       x -= width;
            //       break;
            //     case GTK_STACK_TRANSITION_TYPE_SLIDE_RIGHT:
            //       x += width;
            //       break;
            //     case GTK_STACK_TRANSITION_TYPE_SLIDE_UP:
            //       y -= height;
            //       break;
            //     case GTK_STACK_TRANSITION_TYPE_SLIDE_DOWN:
            //       y += height;
            //       break;
            //     case GTK_STACK_TRANSITION_TYPE_OVER_UP:
            //     case GTK_STACK_TRANSITION_TYPE_OVER_DOWN:
            //       y = 0;
            //       break;
            //     case GTK_STACK_TRANSITION_TYPE_OVER_LEFT:
            //     case GTK_STACK_TRANSITION_TYPE_OVER_RIGHT:
            //       x = 0;
            //       break;
            //     default:
            //       g_assert_not_reached ();
            //       break;
            //     }


            // if (priv->last_visible_child != NULL)
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
            this.snapshot_child (child, snapshot);
            snapshot.restore ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var child = this.child;

            if (child != null && child.visible)
            {
                if (this.state != RevealerState.OPENED)
                {
                    var bounds = Graphene.Rect ();
                    bounds.init (
                        0,
                        0,
                        this.get_width (),
                        this.get_height ()
                    );

                    snapshot.push_clip (bounds);
                    this.snapshot_slide (snapshot);
                    snapshot.pop ();
                }
                else {
                    this.snapshot_child (child, snapshot);
                }
            }
        }


        // public override void size_allocate (int width,
        //                                     int height,
        //                                     int baseline)
        // {
        //     var progress = this.get_progress ();
        //     var original_width  = this.get_width ();
        //     var original_height = this.get_height ();

            // GtkStack *stack = GTK_STACK (widget);
            // GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
        //     var child_allocation = Gtk.Allocation () {
        //         x = 0;
        //         y = 0;
        //         width = width;
        //         height = height;
        //     };
        //     var child = this.child;

        //     if (child)
        //     {
        //         int min_width;
        //         int min_height;

        //         gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_HORIZONTAL,
        //                           height, &min_width, NULL, NULL, NULL);
        //         child_allocation.width = MAX (child_allocation.width, min_width);

        //         gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_VERTICAL,
        //                           child_allocation.width, &min_height, NULL, NULL, NULL);
        //         child_allocation.height = MAX (child_allocation.height, min_height);

        //         if (child_allocation.width > width)
        //         {
        //           GtkAlign halign = gtk_widget_get_halign (priv->visible_child->widget);

        //           if (halign == GTK_ALIGN_CENTER || halign == GTK_ALIGN_FILL)
        //             child_allocation.x = (width - child_allocation.width) / 2;
        //           else if (halign == GTK_ALIGN_END)
        //             child_allocation.x = (width - child_allocation.width);
        //         }

        //         if (child_allocation.height > height)
        //         {
        //           GtkAlign valign = gtk_widget_get_valign (priv->visible_child->widget);

        //           if (valign == GTK_ALIGN_CENTER || valign == GTK_ALIGN_FILL)
        //             child_allocation.y = (height - child_allocation.height) / 2;
        //           else if (valign == GTK_ALIGN_END)
        //             child_allocation.y = (height - child_allocation.height);
        //         }

        //         gtk_widget_size_allocate (priv->visible_child->widget, &child_allocation, -1);
        //     }
        // }

        // static void
        // gtk_stack_size_allocate (GtkWidget *widget,
        //                          int        width,
        //                          int        height,
        //                          int        baseline)
        // {
        //   GtkStack *stack = GTK_STACK (widget);
        //   GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
        //   GtkAllocation child_allocation;

        //   if (priv->last_visible_child)
        //     {
        //       int child_width, child_height;
        //       int min, nat;

        //       gtk_widget_measure (priv->last_visible_child->widget, GTK_ORIENTATION_HORIZONTAL,
        //                           -1,
        //                           &min, &nat, NULL, NULL);
        //       child_width = MAX (min, width);
        //       gtk_widget_measure (priv->last_visible_child->widget, GTK_ORIENTATION_VERTICAL,
        //                           child_width,
        //                           &min, &nat, NULL, NULL);
        //       child_height = MAX (min, height);

        //       gtk_widget_size_allocate (priv->last_visible_child->widget,
        //                                 &(GtkAllocation) { 0, 0, child_width, child_height }, -1);
        //     }

        //   child_allocation.x = get_bin_window_x (stack);
        //   child_allocation.y = get_bin_window_y (stack);
        //   child_allocation.width = width;
        //   child_allocation.height = height;

        //   if (priv->visible_child)
        //     {
        //       int min_width;
        //       int min_height;

        //       gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_HORIZONTAL,
        //                           height, &min_width, NULL, NULL, NULL);
        //       child_allocation.width = MAX (child_allocation.width, min_width);

        //       gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_VERTICAL,
        //                           child_allocation.width, &min_height, NULL, NULL, NULL);
        //       child_allocation.height = MAX (child_allocation.height, min_height);

        //       if (child_allocation.width > width)
        //         {
        //           GtkAlign halign = gtk_widget_get_halign (priv->visible_child->widget);

        //           if (halign == GTK_ALIGN_CENTER || halign == GTK_ALIGN_FILL)
        //             child_allocation.x = (width - child_allocation.width) / 2;
        //           else if (halign == GTK_ALIGN_END)
        //             child_allocation.x = (width - child_allocation.width);
        //         }

        //       if (child_allocation.height > height)
        //         {
        //           GtkAlign valign = gtk_widget_get_valign (priv->visible_child->widget);

        //           if (valign == GTK_ALIGN_CENTER || valign == GTK_ALIGN_FILL)
        //             child_allocation.y = (height - child_allocation.height) / 2;
        //           else if (valign == GTK_ALIGN_END)
        //             child_allocation.y = (height - child_allocation.height);
        //         }

        //       gtk_widget_size_allocate (priv->visible_child->widget, &child_allocation, -1);
        //     }
        // }

        // #define LERP(a, b, t) ((a) + (((b) - (a)) * (1.0 - (t))))
        // static void
        // gtk_stack_measure (GtkWidget      *widget,
        //                    GtkOrientation  orientation,
        //                    int             for_size,
        //                    int            *minimum,
        //                    int            *natural,
        //                    int            *minimum_baseline,
        //                    int            *natural_baseline)
        // {
        //   GtkStack *stack = GTK_STACK (widget);
        //   GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
        //   GtkStackPage *child_info;
        //   GtkWidget *child;
        //   int child_min, child_nat;
        //   GList *l;

        //   *minimum = 0;
        //   *natural = 0;

        //   for (l = priv->children; l != NULL; l = l->next)
        //     {
        //       child_info = l->data;
        //       child = child_info->widget;

        //       if (!priv->homogeneous[orientation] &&
        //           priv->visible_child != child_info)
        //         continue;

        //       if (gtk_widget_get_visible (child))
        //         {
        //           if (!priv->homogeneous[OPPOSITE_ORIENTATION(orientation)] && priv->visible_child != child_info)
        //             {
        //               int min_for_size;

        //               gtk_widget_measure (child, OPPOSITE_ORIENTATION (orientation), -1, &min_for_size, NULL, NULL, NULL);

        //               gtk_widget_measure (child, orientation, MAX (min_for_size, for_size), &child_min, &child_nat, NULL, NULL);
        //             }
        //           else
        //             gtk_widget_measure (child, orientation, for_size, &child_min, &child_nat, NULL, NULL);

        //           *minimum = MAX (*minimum, child_min);
        //           *natural = MAX (*natural, child_nat);
        //         }
        //     }

        //   if (priv->last_visible_child != NULL && !priv->homogeneous[orientation])
        //     {
        //       double t = priv->interpolate_size ? gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE) : 1.0;
        //       int last_size;

        //       if (orientation == GTK_ORIENTATION_HORIZONTAL)
        //         last_size = priv->last_visible_widget_width;
        //       else
        //         last_size = priv->last_visible_widget_height;

        //       *minimum = LERP (*minimum, last_size, t);
        //       *natural = LERP (*natural, last_size, t);
        //     }
        // }
    }
*/


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
            // public char *name;
            // public char *title;
            // public char *icon_name;
            public unowned Gtk.Widget? last_focus = null;

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
                return this._visible_child;
            }
            set {
                assert (value.parent == this);

                // this._visible_child = value;
                this.set_visible_child_internal (value);
            }
        }

        public uint visible_child_index {  // TODO: remove
            get {
                var child_info = this.find_child_info_for_widget (this._visible_child);

                return this.children.index (child_info);
            }
            set {
                var child_info = this.children.nth_data (value);

                this.visible_child = child_info.widget;
            }
        }

        // The animation duration, in milliseconds.
        public uint transition_duration { get; set construct; default = 300; }

        // The type of animation used to transition.
        // public Pomodoro.AlignedStackTransitionType transition_type { get; set construct; }

        // public float xorigin { get; set; default=0.5f }
        // public float yorigin { get; set; default=0.5f }

        private unowned Gtk.Widget? _visible_child;
        private unowned Gtk.Widget? last_visible_child;
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

        private void set_visible_child_internal (Gtk.Widget child)
        {
            // GtkWidget *focus;
            // gboolean contains_focus = FALSE;

          /* if we are being destroyed, do not bother with transitions
           * and notifications
           */
            if (this.in_destruction ()) {
                return;
            }

            if (this.last_visible_child != null) {
                this.last_visible_child.set_child_visible (false);
            }

            if (this._visible_child != null) {
                this._visible_child.set_child_visible (false);  // TODO: do this after animation
                this.last_visible_child = this._visible_child;
            }

            this._visible_child = child;
            this._visible_child.set_child_visible (true);

            this.queue_resize ();

            // TODO: setup transition
        }

        private void update_child_visible ()
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;
            var transition_progress = this.get_transition_progress ();

            if (visible_child != null) {
                visible_child.set_child_visible (true);
            }

            if (last_visible_child != null) {
                last_visible_child.set_child_visible (transition_progress < 1.0);
            }

            // gtk_accessible_update_state (GTK_ACCESSIBLE (child_info),
            //                            GTK_ACCESSIBLE_STATE_HIDDEN, !visible,
            //                            -1);
        }

        // TODO: call this.animation.skip () if widget gets unmapped
        // if (!gtk_widget_get_mapped (widget))
        //     gtk_progress_tracker_finish (&priv->tracker);

        // TODO: handle child changes

        // TODO: handle child.notify["visibility"]

        private void add_child_internal (Gtk.Widget child)
        {
            var child_info = new ChildInfo (child);

            this.children.append (child_info);

            child.set_child_visible (false);
            child.set_parent (this);

            if (this._visible_child == null && child.visible) {
                this.set_visible_child_internal (child);
                // this.queue_resize ();  // TODO?
            }
            else {
                child.visible = false;
            }

          //   if (priv->pages)
          //   {
          //       g_list_model_items_changed (G_LIST_MODEL (priv->pages), g_list_length (priv->children) - 1, 0, 1);
          //       g_object_notify_by_pspec (G_OBJECT (priv->pages), pages_properties[PAGES_PROP_N_ITEMS]);
          //   }

          // g_signal_connect (child_info->widget, "notify::visible",
          //                   G_CALLBACK (stack_child_visibility_notify_cb), stack);

          // if (priv->visible_child == NULL &&
          //     gtk_widget_get_visible (child_info->widget))
          //   set_visible_child (stack, child_info, priv->transition_type, priv->transition_duration);

            // if (priv->homogeneous[GTK_ORIENTATION_HORIZONTAL] ||
            //     priv->homogeneous[GTK_ORIENTATION_VERTICAL] ||
            //     this._visible_child == child)
            // {
            //     this.queue_resize ();
            // }
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

            if (this._visible_child == child) {
                this._visible_child = null;
            }

            if (this.last_visible_child == child) {
                this.last_visible_child = null;
            }

            child.unparent ();

            // link.data = null;  // XXX
            // g_clear_object (&child_info->widget);

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
            // unowned GLib.List<Gtk.Widget> link;
            // unowned Gtk.Widget? child;

            hexpand = false;
            vexpand = false;

            // while (link != null)
            // for (link = this.children; link != null; link = link.next)
            // {
            //     child = (Gtk.Widget) link.data;

            //     if (!hexpand && child.compute_expand (Gtk.Orientation.HORIZONTAL)) {
            //         hexpand = true;
            //     }

            //     if (!vexpand && child.compute_expand (Gtk.Orientation.VERTICAL)) {
            //         vexpand = true;
            //     }

                // link = link.next;
                // vexpand |= child.compute_expand (Gtk.Orientation.VERTICAL);
            // }
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            /*
            unowned GLib.List<Gtk.Widget> link;  // = this.children.first ();
            unowned Gtk.Widget? child;

            var width_for_height = 0;
            var height_for_width = 0;

            for (link = this.children; link != null; link = link.next)
            // while (link != null)
            {
                child = (Gtk.Widget) link.data;

            // this.children.@foreach ((child) => {

                switch (child.get_request_mode ())
                {
                    case Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH:
                        height_for_width++;
                        break;

                    case Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT:
                        width_for_height++;
                        break;

                    case Gtk.SizeRequestMode.CONSTANT_SIZE:
                    default:
                        break;
                }
            // });

                // link = link.next;
            }

            if (this._visible_child is Adw.HeaderBar)
            {
                return Gtk.SizeRequestMode.CONSTANT_SIZE;

                // warning ("### measure %s %d: %d", (orientation == Gtk.Orientation.HORIZONTAL ? "H" : "V"), for_size, natural);
            }

            if (height_for_width == 0 && width_for_height == 0) {
                return Gtk.SizeRequestMode.CONSTANT_SIZE;
            }
            else {
                return width_for_height > height_for_width
                    ? Gtk.SizeRequestMode.WIDTH_FOR_HEIGHT
                    : Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
            }
            */

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
            var child_minimum_baseline = 0;
            var child_natural_baseline = 0;
            var dummy = 0;
            var expand = false;

            minimum = 0;
            natural = 0;
            minimum_baseline = -1;
            natural_baseline = -1;

            /*
            for (link = this.children; link != null; link = link.next)
            {
                child = (Gtk.Widget) link.data;
                child.measure (orientation,
                               for_size,
                               out child_minimum,
                               out child_natural,
                               out child_minimum_baseline,
                               out child_natural_baseline);

                minimum          = int.max (minimum, child_minimum);
                minimum_baseline = int.max (minimum_baseline, child_minimum_baseline);

                // if (minimum < child_minimum) {
                //     minimum = child_minimum;
                // }
                // if (natural < child_natural) {
                //     natural = child_natural;
                // }
                // if (minimum_baseline < child_minimum_baseline) {
                //     minimum_baseline = child_minimum_baseline;
                // }
                // if (natural_baseline < child_natural_baseline) {
                //     natural_baseline = child_natural_baseline;
                // }

                if (child == this._visible_child)
                {
                    natural          = int.max (natural, child_natural);
                    natural_baseline = int.max (natural_baseline, child_natural_baseline);

                    // if (natural < child_natural) {
                    //     natural = child_natural;
                    // }

                    // if (natural_baseline < child_natural_baseline) {
                    //     natural_baseline = child_natural_baseline;
                    // }
                }
            }
            */

            if (this._visible_child != null)
            {
                switch (orientation)
                {
                    case Gtk.Orientation.HORIZONTAL:
                        expand = this._visible_child.hexpand_set && this._visible_child.hexpand;
                        break;

                    case Gtk.Orientation.VERTICAL:
                        expand = this._visible_child.vexpand_set && this._visible_child.vexpand;
                        break;

                    default:
                        break;
                }

                this._visible_child.measure (orientation,
                                             for_size,
                                             out minimum,
                                             out natural,
                                             out dummy,
                                             out dummy);
            }

            // natural          = int.max (natural, minimum);
            // natural_baseline = int.max (natural_baseline, minimum_baseline);

            // if (natural < minimum) {
            //     natural = minimum;
            // }

            // if (natural_baseline < minimum_baseline) {
            //     natural_baseline = minimum_baseline;
            // }


            // if (this._visible_child != null)
            // {
            //     this._visible_child.measure (orientation,
            //                                  for_size,
            //                                  out minimum,
            //                                  out natural,
            //                                  out minimum_baseline,
            //                                  out natural_baseline);
            // }

            // if (for_size < 0 && !expand) {
            //     natural = minimum;
            // }

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

            // warning ("### measure %s %d: %d", (orientation == Gtk.Orientation.HORIZONTAL ? "H" : "V"), for_size, natural);

            // TODO: animate size here

              // double t = priv->interpolate_size ? gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE) : 1.0;
              // int last_size;
              //
              // if (orientation == GTK_ORIENTATION_HORIZONTAL)
              //   last_size = priv->last_visible_widget_width;
              // else
              //   last_size = priv->last_visible_widget_height;
              //
              // *minimum = LERP (*minimum, last_size, t);
              // *natural = LERP (*natural, last_size, t);




            // base.measure (orientation,
            //                 for_size,
            //                 out minimum,
            //                 out natural,
            //                 out minimum_baseline,
            //                 out natural_baseline);

          // GtkStack *stack = GTK_STACK (widget);
          // GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
          // GtkStackPage *child_info;
          // GtkWidget *child;
          // int child_min, child_nat;
          // GList *l;

          // *minimum = 0;
          // *natural = 0;

          // for (l = priv->children; l != NULL; l = l->next)
          //   {
          //     child_info = l->data;
          //     child = child_info->widget;

          //     if (!priv->homogeneous[orientation] &&
          //         priv->visible_child != child_info)
          //       continue;

          //     if (gtk_widget_get_visible (child))
          //       {
          //         if (!priv->homogeneous[OPPOSITE_ORIENTATION(orientation)] && priv->visible_child != child_info)
          //           {
          //             int min_for_size;

          //             gtk_widget_measure (child, OPPOSITE_ORIENTATION (orientation), -1, &min_for_size, NULL, NULL, NULL);

          //             gtk_widget_measure (child, orientation, MAX (min_for_size, for_size), &child_min, &child_nat, NULL, NULL);
          //           }
          //         else
          //           gtk_widget_measure (child, orientation, for_size, &child_min, &child_nat, NULL, NULL);

          //         *minimum = MAX (*minimum, child_min);
          //         *natural = MAX (*natural, child_nat);
          //       }
          //   }

          // if (priv->last_visible_child != NULL && !priv->homogeneous[orientation])
          //   {
          //     double t = priv->interpolate_size ? gtk_progress_tracker_get_ease_out_cubic (&priv->tracker, FALSE) : 1.0;
          //     int last_size;

          //     if (orientation == GTK_ORIENTATION_HORIZONTAL)
          //       last_size = priv->last_visible_widget_width;
          //     else
          //       last_size = priv->last_visible_widget_height;

          //     *minimum = LERP (*minimum, last_size, t);
          //     *natural = LERP (*natural, last_size, t);
          //   }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            // warning ("### size_allocate %dx%d", width, height);

            var visible_child      = this._visible_child;
            var last_visible_child = this.last_visible_child;
            var progress           = this.get_transition_progress ();
            var original_width     = this.get_width ();
            var original_height    = this.get_height ();

            // GtkStack *stack = GTK_STACK (widget);
            // GtkStackPrivate *priv = gtk_stack_get_instance_private (stack);
            var child_allocation = Gtk.Allocation () {
                x = 0,
                y = 0,
                width = width,
                height = height
            };
            // var child = this.child;

            // warning ("size_allocate: %dx%d", width, height);

            if (visible_child != null)
            {
                // int min_width;
                // int min_height;

                // gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_HORIZONTAL,
                //                   height, &min_width, NULL, NULL, NULL);
                // child_allocation.width = MAX (child_allocation.width, min_width);

                // gtk_widget_measure (priv->visible_child->widget, GTK_ORIENTATION_VERTICAL,
                //                   child_allocation.width, &min_height, NULL, NULL, NULL);
                // child_allocation.height = MAX (child_allocation.height, min_height);

                // if (child_allocation.width > width)
                // {
                //   GtkAlign halign = gtk_widget_get_halign (priv->visible_child->widget);

                //   if (halign == GTK_ALIGN_CENTER || halign == GTK_ALIGN_FILL)
                //     child_allocation.x = (width - child_allocation.width) / 2;
                //   else if (halign == GTK_ALIGN_END)
                //     child_allocation.x = (width - child_allocation.width);
                // }

                // if (child_allocation.height > height)
                // {
                //   GtkAlign valign = gtk_widget_get_valign (priv->visible_child->widget);

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

                visible_child.allocate_size (child_allocation, -1);
            }
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
            this.snapshot_child (visible_child, snapshot);
            snapshot.restore ();
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            var visible_child = this._visible_child;
            var last_visible_child = this.last_visible_child;

            if (visible_child != null && visible_child.visible)
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
                    this.snapshot_child (visible_child, snapshot);
                }
            }
        }

        public override bool focus (Gtk.DirectionType direction)
        {
            return this._visible_child != null
                ? this._visible_child.focus (direction)
                : false;
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



}
