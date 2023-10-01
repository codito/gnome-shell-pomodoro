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
}
