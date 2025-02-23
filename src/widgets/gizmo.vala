namespace Pomodoro
{
    public delegate void GizmoMeasureFunc (Pomodoro.Gizmo gizmo,
                                           Gtk.Orientation orientation,
                                           int for_size,
                                           out int minimum,
                                           out int natural,
                                           out int minimum_baseline,
                                           out int natural_baseline);
    public delegate void GizmoAllocateFunc (Pomodoro.Gizmo gizmo, int width, int height, int baseline);
    public delegate void GizmoSnapshotFunc (Pomodoro.Gizmo gizmo, Gtk.Snapshot snapshot);
    public delegate bool GizmoContainsFunc (Pomodoro.Gizmo gizmo, double x, double y);
    public delegate bool GizmoFocusFunc (Pomodoro.Gizmo gizmo, Gtk.DirectionType direction);
    public delegate bool GizmoGrabFocusFunc (Pomodoro.Gizmo gizmo);


    /**
     * A widget that is controlled by its parent.
     *
     * It's a carbon copy from Gtk+ code. File gtk/gtk/gtkgizmo.c
     */
    public sealed class Gizmo : Gtk.Widget
    {
        private Pomodoro.GizmoMeasureFunc?   measure_func;
        private Pomodoro.GizmoAllocateFunc?  allocate_func;
        private Pomodoro.GizmoSnapshotFunc?  snapshot_func;
        private Pomodoro.GizmoContainsFunc?  contains_func;
        private Pomodoro.GizmoFocusFunc?     focus_func;
        private Pomodoro.GizmoGrabFocusFunc? grab_focus_func;

        public Gizmo (owned Pomodoro.GizmoMeasureFunc?   measure_func,
                      owned Pomodoro.GizmoAllocateFunc?  allocate_func,
                      owned Pomodoro.GizmoSnapshotFunc?  snapshot_func,
                      owned Pomodoro.GizmoContainsFunc?  contains_func,
                      owned Pomodoro.GizmoFocusFunc?     focus_func,
                      owned Pomodoro.GizmoGrabFocusFunc? grab_focus_func)
        {
            this.measure_func  = (owned) measure_func;
            this.allocate_func = (owned) allocate_func;
            this.snapshot_func = (owned) snapshot_func;
            this.contains_func = (owned) contains_func;
            this.focus_func = (owned) focus_func;
            this.grab_focus_func = (owned) grab_focus_func;
        }

        public Gizmo.with_role (Gtk.AccessibleRole                 role,
                                owned Pomodoro.GizmoMeasureFunc?   measure_func,
                                owned Pomodoro.GizmoAllocateFunc?  allocate_func,
                                owned Pomodoro.GizmoSnapshotFunc?  snapshot_func,
                                owned Pomodoro.GizmoContainsFunc?  contains_func,
                                owned Pomodoro.GizmoFocusFunc?     focus_func,
                                owned Pomodoro.GizmoGrabFocusFunc? grab_focus_func)
        {
            GLib.Object (
                accessible_role: role
            );

            this.measure_func  = (owned) measure_func;
            this.allocate_func = (owned) allocate_func;
            this.snapshot_func = (owned) snapshot_func;
            this.contains_func = (owned) contains_func;
            this.focus_func = (owned) focus_func;
            this.grab_focus_func = (owned) grab_focus_func;
        }

        ~Gizmo ()
        {
            var child = this.get_first_child ();

            while (child != null)
            {
                var next_child = child.get_next_sibling ();
                child.unparent ();
                child = next_child;
            }
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }

        public override void measure (Gtk.Orientation orientation,
                                      int for_size,
                                      out int minimum,
                                      out int natural,
                                      out int minimum_baseline,
                                      out int natural_baseline)
        {
            if (this.measure_func != null) {
                this.measure_func (this,
                                   orientation,
                                   for_size,
                                   out minimum,
                                   out natural,
                                   out minimum_baseline,
                                   out natural_baseline);
            }
            else {
                minimum = 0;
                natural = for_size;
                minimum_baseline = -1;
                natural_baseline = -1;
            }
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            if (this.allocate_func != null) {
                this.allocate_func (this, width, height, baseline);
            }
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            if (this.snapshot_func != null) {
                this.snapshot_func (this, snapshot);
            }
            else {
                base.snapshot (snapshot);
            }
        }

        public override bool contains (double x,
                                       double y)
        {
            if (this.contains_func != null) {
                return this.contains_func (this, x, y);
            }

            return base.contains (x, y);
        }

        public override bool focus (Gtk.DirectionType direction)
        {
            if (this.focus_func != null) {
                return this.focus_func (this, direction);
            }

            return false;
        }

        public override bool grab_focus ()
        {
            if (this.grab_focus_func != null) {
                return this.grab_focus_func (this);
            }

            return false;
        }
    }
}
