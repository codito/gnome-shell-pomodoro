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

    internal void wake_up_screen ()
    {
        // org.freedesktop.ScreenSaver SimulateUserActivity (does not work?)
    }

    internal void lock_screen ()
    {
        // session bus:
        // org.gnome.Shell.ScreenShield Lock
        // /org/gnome/ScreenSaver
        // org.freedesktop.ScreenSaver Lock (does not work)

        // system:
        // org.freedesktop.login1.Manager LockSession (requires permissions)
        // org.freedesktop.login1.Manager LockSessions (requires permissions)
    }
}
