/*
 * Copyright (c) 2025 gnome-pomodoro contributors
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Authors: Kamil Prusko <kamilprusko@gmail.com>
 *
 */

using GLib;


namespace Pomodoro
{
    public class CanvasItem : GLib.Object
    {
        public Gtk.Widget child {
            get {
                return this._child;
            }
            construct {
                this._child = value != null ? value : this.create_child ();
            }
        }

        /**
         * Position in the value space.
         */
        public float x { get; set; default = 0.0f; }

        /**
         * Position in the value space.
         */
        public float y { get; set; default = 0.0f; }

        /**
         * Offset from the child's top-left corner in pixels.
         */
        public int x_origin { get; set; default = 0; }

        /**
         * Offset from the child's top-left corner in pixels.
         */
        public int y_origin { get; set; default = 0; }

        private Gtk.Widget? _child;

        internal Gtk.Allocation allocation;

        public CanvasItem (Gtk.Widget child)
        {
            GLib.Object (
                child: child
            );
        }

        // XXX: add x_scale / y_scale arguments?
        public Gdk.Rectangle compute_bounds ()
        {
            var bounds = Gdk.Rectangle () {
                x      = -this.x_origin,
                y      = -this.y_origin
            };

            if (this.child != null)
            {
                this.child.measure (Gtk.Orientation.HORIZONTAL,
                                    -1,
                                    null,
                                    out bounds.width,
                                    null,
                                    null);
                this.child.measure (Gtk.Orientation.VERTICAL,
                                    -1,
                                    null,
                                    out bounds.height,
                                    null,
                                    null);
            }

            return bounds;
        }

        protected virtual Gtk.Widget? create_child ()
        {
            return null;
        }

        public override void dispose ()
        {
            this._child = null;

            base.dispose ();
        }
    }


    /**
     * A container for placing children at a given coordinates in a user-defined value space -
     * not pixels. Value space is defined by `x-scale` and `y-scale`. `Canvas` will stretch to
     * accommodate all children. During allocation, it will track the origin point and compute the
     * `transform` between pixels and the value space.
     *
     * Unlike in GTK+, the y-coordinates increase when going up (like in typical charts) and
     * items are positioned from bottom-left corner.
     * Worth a read: https://docs.gtk.org/gtk4/coordinates.html
     */
    public sealed class Canvas : Gtk.Widget
    {
        private const double EPSILON = 0.00001;
        private const bool   DEBUG = false;

        public float x_scale {
            get {
                return this._x_scale;
            }
            set {
                this._x_scale = value;

                this.queue_resize ();
            }
        }

        public float y_scale {
            get {
                return this._y_scale;
            }
            set {
                this._y_scale = value;

                this.queue_resize ();
            }
        }

        /**
         * Offset between top-left corner and an origin point.
         */
        public int x_origin {
            get {
                return this._x_origin;
            }
        }

        /**
         * Offset between top-left corner and an origin point.
         */
        public int y_origin {
            get {
                return this._y_origin;
            }
        }

        /**
         * Transform from pixels to value space
         */
        public Gsk.Transform? transform {
            get {
                return this._transform;
            }
        }

        private GLib.List<Pomodoro.CanvasItem> items;
        private float                          _x_scale = 1.0f;
        private float                          _y_scale = 1.0f;
        private int                            _x_origin = 0;
        private int                            _y_origin = 0;
        private Gsk.Transform?                 _transform = null;
        private Gsk.Transform?                 _transform_inv = null;

        static construct
        {
            set_css_name ("canvas");
        }

        construct
        {
            if (DEBUG)
            {
                var click_gesture = new Gtk.GestureClick ();
                click_gesture.pressed.connect (
                    (n_press, x, y) => {
                        var point = Graphene.Point () {
                            x = (float) x,
                            y = (float) y
                        };
                        point = this.transform.transform_point (point);
                    });

                this.add_controller (click_gesture);
            }
        }

        private void update_transform ()
        {
            if (float.min (this._x_scale.abs (), this._y_scale.abs ()) > EPSILON)
            {
                var transform = new Gsk.Transform ();
                transform = transform.scale (1.0f / this._x_scale, -1.0f / this._y_scale);
                transform = transform.translate (
                    Graphene.Point () {
                        x = (float) (-this._x_origin),
                        y = (float) (-this._y_origin)
                    });
                this._transform     = transform;
                this._transform_inv = transform.invert ();
            }
            else {
                this._transform     = null;
                this._transform_inv = null;
            }
        }

        private void add_child_internal (Pomodoro.CanvasItem item)
        {
            this.items.append (item);

            item.child.insert_after (this, this.get_last_child ());
        }

        private void remove_child_internal (GLib.List<Pomodoro.CanvasItem> link,
                                            bool                           in_dispose = false)
        {
            var child = link.data.child;

            child.unparent ();

            this.items.remove_link (link);
        }

        public void add_item (Pomodoro.CanvasItem item)
        {
            if (this.items.index (item) >= 0) {
                return;
            }

            this.add_child_internal (item);

            this.queue_resize ();
        }

        public void remove_item (Pomodoro.CanvasItem item)
        {
            unowned var link = this.items.find (item);

            if (link != null) {
                this.remove_child_internal (link);
            }

            this.queue_resize ();
        }

        public void @foreach (GLib.Func<unowned Pomodoro.CanvasItem> func)
        {
            unowned var link = this.items.first ();

            while (link != null)
            {
                unowned var next_link = link.next;

                func (link.data);

                link = next_link;
            }
        }

        private inline Gdk.Rectangle compute_item_bounds (Pomodoro.CanvasItem item)
        {
            var bounds = item.compute_bounds ();

            bounds.x += (int) Math.roundf (this._x_scale * item.x);
            bounds.y -= (int) Math.roundf (this._y_scale * item.y);

            return bounds;
        }

        private bool compute_items_bounds (out Gdk.Rectangle bounds)
        {
            unowned var link = this.items.first ();

            if (link == null)
            {
                bounds = Gdk.Rectangle ();

                return false;
            }

            bounds = this.compute_item_bounds (link.data);
            link   = link.next;

            while (link != null)
            {
                bounds.union (this.compute_item_bounds (link.data), out bounds);
                link = link.next;
            }

            // TODO: cache bounds, as `measure()` may be executed frequently

            return true;
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
            Gdk.Rectangle bounds;

            if (this.compute_items_bounds (out bounds)) {
                natural = orientation == Gtk.Orientation.HORIZONTAL
                        ? bounds.width : bounds.height;
            }
            else {
                natural = 0;
            }

            minimum          = natural;
            minimum_baseline = -1;
            natural_baseline = -1;
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            unowned var link = this.items.first ();
            var bounds       = Gtk.Allocation ();
            var x_origin     = 0;
            var y_origin     = 0;

            while (link != null)
            {
                unowned var item  = link.data;
                var item_bounds   = this.compute_item_bounds (item);

                item.allocation = Gtk.Allocation () {
                    x      = item_bounds.x,
                    y      = item_bounds.y,
                    width  = item_bounds.width,
                    height = item_bounds.height
                };

                if (x_origin > item.allocation.x + item.x_origin) {
                    x_origin = item.allocation.x + item.x_origin;
                }

                if (y_origin < item.allocation.y + item.y_origin) {
                    y_origin = item.allocation.y + item.y_origin;
                }

                bounds.union (item.allocation, out bounds);

                link = link.next;
            }

            for (link = this.items.first (); link != null; link = link.next)
            {
                unowned var item = link.data;
                item.allocation.x -= bounds.x;
                item.allocation.y -= bounds.y;
                item.child.allocate_size (item.allocation, -1);
            }

            this._x_origin = x_origin - bounds.x;
            this._y_origin = y_origin - bounds.y;

            this.update_transform ();  // TODO: just invalidate, no need to compute
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            unowned GLib.List<Pomodoro.CanvasItem> link = this.items.first ();

            while (link != null)
            {
                this.snapshot_child (link.data.child, snapshot);

                link = link.next;
            }

            if (DEBUG)
            {
                var is_guides = this.x_scale == 1.0;
                var color = Gdk.RGBA () {
                    red   = is_guides ? 0.0f : 1.0f,
                    green = 0.0f,
                    blue  = is_guides ? 1.0f : 0.0f,
                    alpha = 1.0f
                };
                var origin = this._transform_inv.transform_point (
                    Graphene.Point () {
                        x = 0.0f,
                        y = 0.0f
                    });
                var stroke = new Gsk.Stroke (2.0f);
                var cross = new Gsk.PathBuilder ();
                cross.move_to (origin.x,      origin.y - 10);
                cross.line_to (origin.x,      origin.y + 10);
                cross.move_to (origin.x - 10, origin.y);
                cross.line_to (origin.x + 10, origin.y);
                snapshot.append_stroke (cross.to_path (), stroke, color);
            }
        }

        public override void dispose ()
        {
            this._transform = null;
            this._transform_inv = null;

            base.dispose ();
        }
    }
}
