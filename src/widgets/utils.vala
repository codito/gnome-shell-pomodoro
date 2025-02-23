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


    internal Gdk.RGBA mix_colors (Gdk.RGBA color_1,
                                  Gdk.RGBA color_2,
                                  float    factor)
    {
        return Gdk.RGBA () {
            red   = (1.0f - factor) * color_1.red   + factor * color_2.red,
            green = (1.0f - factor) * color_1.green + factor * color_2.green,
            blue  = (1.0f - factor) * color_1.blue  + factor * color_2.blue,
            alpha = (1.0f - factor) * color_1.alpha + factor * color_2.alpha,
        };
    }


    internal Gdk.RGBA get_foreground_color (Gtk.Widget widget)
    {
        var style_context = widget.get_style_context ();

        Gdk.RGBA color;
        style_context.lookup_color ("theme_fg_color", out color);

        return color;
    }


    internal Gdk.RGBA get_background_color (Gtk.Widget widget)
    {
        var style_context = widget.get_style_context ();

        Gdk.RGBA color;
        style_context.lookup_color ("theme_bg_color", out color);

        return color;
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


    internal string capitalize_words (string text)
    {
        var string_builder = new GLib.StringBuilder ();
        var capitalize_next = true;
        int index = 0;
        unichar chr;

        while (text.get_next_char (ref index, out chr))
        {
            if (chr == ' ') {
                string_builder.append_unichar (chr);
                capitalize_next = true;
            }
            else if (capitalize_next && chr.islower ()) {
                string_builder.append_unichar (chr.toupper ());
                capitalize_next = false;
            }
            else {
                string_builder.append_unichar (chr);
                capitalize_next = false;
            }
        }

        return string_builder.str;
    }
}
