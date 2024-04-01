namespace Pomodoro
{
    internal Gdk.RGBA blend_colors (Gdk.RGBA base_color,
                                    Gdk.RGBA overlay_color)
    {
        return Gdk.RGBA () {
            red   = (1.0f - overlay_color.alpha) * base_color.red   + overlay_color.alpha * overlay_color.red,
            green = (1.0f - overlay_color.alpha) * base_color.green + overlay_color.alpha * overlay_color.green,
            blue  = (1.0f - overlay_color.alpha) * base_color.blue  + overlay_color.alpha * overlay_color.blue,
            alpha = base_color.alpha + (1.0f - base_color.alpha) * overlay_color.alpha,
        };
    }


    internal unowned Gtk.Widget? get_child_by_buildable_id (Gtk.Widget widget,
                                                            string     buildable_id)
    {
        unowned var child = widget.get_first_child ();

        while (child != null)
        {
            if (child.get_buildable_id () == buildable_id) {
                return child;
            }

            unowned var nested_child = get_child_by_buildable_id (child, buildable_id);
            if (nested_child != null) {
                return nested_child;
            }

            child = child.get_next_sibling ();
        }

        return null;
    }
}
