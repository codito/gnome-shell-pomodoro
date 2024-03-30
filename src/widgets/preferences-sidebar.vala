namespace Pomodoro
{
    public class PreferencesSidebar : Gtk.Widget
    {
        public Gtk.SingleSelection model
        {
            get {
                return this._model;
            }
            set {
                if (this._model == value) {
                    return;
                }

                if (this._model != null) {
                    this._model.items_changed.disconnect (this.on_model_items_changed);
                }

                this.clear ();

                this._model = value;

                this.populate ();

                if (this._model != null) {
                    this._model.items_changed.connect (this.on_model_items_changed);
                }

                this.notify_property ("model");
            }
        }

        public Gtk.SelectionMode selection_mode
        {
            get {
                return this.list.selection_mode;
            }
            set {
                this.list.selection_mode = value;

                if (this.list.selection_mode != Gtk.SelectionMode.NONE)
                {
                    var active_row = this.list.get_row_at_index ((int) this._model.selected);

                    this.list.select_row (active_row);
                }
            }
        }

        private Gtk.SingleSelection? _model;
        private Gtk.ListBox?         list;

        construct
        {
            this.layout_manager = new Gtk.BinLayout ();

            var scrolled_window = new Gtk.ScrolledWindow ();
            scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_parent (this);

            this.list = new Gtk.ListBox ();
            this.list.add_css_class ("navigation-sidebar");
            this.list.update_property (Gtk.AccessibleProperty.LABEL,
                                       C_("accessibility", "Sidebar"),
                                       -1);
            scrolled_window.set_child (this.list);

            this.list.row_selected.connect (this.on_row_selected);
            this.list.row_activated.connect (this.on_row_activated);

            this.add_css_class ("sidebar");
        }

        private void add_row (uint position)
        {
            var icon = new Gtk.Image ();

            var label = new Gtk.Label ("");
            label.halign = Gtk.Align.START;
            label.valign = Gtk.Align.CENTER;

            var page = this._model.get_item (position);
            page.bind_property ("title", label, "label", GLib.BindingFlags.SYNC_CREATE);
            page.bind_property ("icon-name", icon, "icon-name", GLib.BindingFlags.SYNC_CREATE);

            var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            hbox.margin_start = 6;
            hbox.margin_end = 6;
            hbox.margin_top = 12;
            hbox.margin_bottom = 12;
            hbox.append (icon);
            hbox.append (label);

            var row = new Gtk.ListBoxRow ();
            row.child = hbox;
            row.update_relation (Gtk.AccessibleRelation.LABELLED_BY, label, null, -1);
            row.set_data<uint> ("child-index", position);

            this.list.append (row);

            if (this._model.is_selected (position)) {
                this.list.select_row (row);
            }
            else {
                this.list.unselect_row (row);
            }
        }

        private void clear ()
        {
            this.list.remove_all ();
        }

        private void populate ()
        {
            var n_items = this._model.get_n_items ();

            for (var position = 0; position < n_items; position++) {
                this.add_row (position);
            }
        }

        private void on_row_selected (Gtk.ListBoxRow? row)
        {
            if (row == null) {
                return;
            }

            var position = row.get_data<uint> ("child-index");

            this._model.select_item (position, true);
        }

        private void on_row_activated (Gtk.ListBoxRow? row)
        {
            var position = row.get_data<uint> ("child-index");

            if (this.selection_mode == Gtk.SelectionMode.NONE) {
                this._model.set_selected (position);
            }
        }

        private void on_model_items_changed (uint position,
                                             uint removed,
                                             uint added)
        {
            this.clear ();
            this.populate ();
        }

        public override void dispose ()
        {
            if (this._model != null) {
                this._model.items_changed.disconnect (this.on_model_items_changed);
                this._model = null;
            }

            if (this.list != null) {
                this.clear ();
                this.list.row_selected.disconnect (this.on_row_selected);
                this.list.row_activated.disconnect (this.on_row_activated);
                this.list = null;
            }

            var child = this.get_first_child ();
            if (child != null) {
                child.unparent ();
            }

            base.dispose ();
        }
    }
}
