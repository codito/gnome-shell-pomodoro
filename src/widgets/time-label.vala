namespace Pomodoro
{
    public sealed class TimeLabel : Gtk.Widget
    {
        public int64 timestamp {
            get {
                return this._timestamp;
            }
            set {
                this._timestamp = value;

                this.update_label ();
            }
        }

        public float xalign {
            get {
                return this.label.xalign;
            }
            set {
                this.label.xalign = value;
            }
        }

        private int64      _timestamp = Pomodoro.Timestamp.UNDEFINED;
        private Gtk.Label? label;

        construct
        {
            this.label = new Gtk.Label (null);
            this.label.ellipsize = Pango.EllipsizeMode.END;
            this.label.single_line_mode = true;
            this.label.wrap = false;
            this.label.set_parent (this);
        }

        private string format_timestamp ()
        {
            if (this._timestamp < 0) {
                return "";
            }

            var seconds = this._timestamp / Pomodoro.Interval.SECOND;
            var datetime = (new GLib.DateTime.from_unix_utc (seconds)).to_local ();

            // TODO: include days ago / relative time
            return datetime.format ("%H:%M");
        }

        private void update_label (int64 timestamp = Pomodoro.Timestamp.UNDEFINED)
        {
            this.label.label = this.format_timestamp ();
        }

        public override Gtk.SizeRequestMode get_request_mode ()
        {
            return Gtk.SizeRequestMode.HEIGHT_FOR_WIDTH;
        }


        /**
         * Estimate size.
         *
         * Interpolate between two children and with-hours / without-hours.
         */
        public override void measure (Gtk.Orientation orientation,
                                      int             for_size,
                                      out int         minimum,
                                      out int         natural,
                                      out int         minimum_baseline,
                                      out int         natural_baseline)
        {
            this.label.measure (orientation,
                                for_size,
                                out minimum,
                                out natural,
                                out minimum_baseline,
                                out natural_baseline);
        }

        public override void size_allocate (int width,
                                            int height,
                                            int baseline)
        {
            var allocation = Gtk.Allocation ();

            this.label.measure (
                              Gtk.Orientation.VERTICAL,
                              height,
                              null,
                              out allocation.height,
                              null,
                              null);
            this.label.measure (
                              Gtk.Orientation.HORIZONTAL,
                              -1,
                              null,
                              out allocation.width,
                              null,
                              null);

            switch (this.halign)
            {
                case Gtk.Align.START:
                    allocation.x = 0;
                    break;

                case Gtk.Align.END:
                    allocation.x = width - allocation.width;
                    break;

                case Gtk.Align.CENTER:
                case Gtk.Align.FILL:
                    allocation.x = (width - allocation.width) / 2;
                    break;

                default:
                    assert_not_reached ();
            }

            allocation.y = (height - allocation.height) / 2;

            this.label.allocate_size (allocation, baseline);
        }

        public override void snapshot (Gtk.Snapshot snapshot)
        {
            this.snapshot_child (this.label, snapshot);
        }

        public override void dispose ()
        {
            if (this.label != null) {
                this.label.unparent ();
                this.label = null;
            }

            base.dispose ();
        }
    }
}
