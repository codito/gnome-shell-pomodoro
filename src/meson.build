# Common library
libgnome_pomodoro_sources = files(
  'about-dialog.vala',
  'accelerator.vala',
  'aggregated-entry.vala',
  'animation.vala',
  'application.vala',
  'capability-group.vala',
  'capability-manager.vala',
  'capability.vala',
  'desktop-extension.vala',
  'entry.vala',
  'log-scale.vala',
  'monospace-label.vala',
  'notifications-capability.vala',
  'preferences-dialog.vala',
  'presence.vala',
  'screen-notification.vala',
  'service.vala',
  'session.vala',
  'session-entry.vala',
  'session-manager.vala',
  'session-manager-strategy.vala',
  'settings.vala',
  'source.vala',
  'state.vala',
  'stats-page.vala',
  'stats-view.vala',
  'stats-day-page.vala',
  'stats-week-page.vala',
  'stats-month-page.vala',
  'time-block.vala',
  'time-block-entry.vala',
  'timeline.vala',
  'timer.vala',
  'timer-view-action-group.vala',
  'timer-label.vala',
  'timer-level-bar.vala',
  'timer-progress-bar.vala',
  'timer-view.vala',
  'timestamp.vala',
  'utils.vala',
  'window.vala',
)

libgnome_pomodoro = static_library(
  'gnome-pomodoro',
  [libgnome_pomodoro_sources, gnome_pomodoro_generated_sources],
  dependencies: [
    gio_dep,
    gobject_dep,
    gom_dep,
    gtk_dep,
    libm_dep,
    peas_dep,
    sqlite_dep,
  ],
  include_directories: config_h_dir,
)

libgnome_pomodoro_dep = declare_dependency(
  link_with: libgnome_pomodoro,
  dependencies: [
    gio_dep,
    gobject_dep,
    peas_dep,
    gtk_dep,
    cairo_dep,
  ],
  include_directories: [
    # Include gnome-pomodoro.h
    include_directories('.'),
  ],
)


# The gnome-pomodoro binary
gnome_pomodoro_sources = files(
  'main.vala',
)

executable(
  'gnome-pomodoro',
  gnome_pomodoro_sources,
  dependencies: [
    libgnome_pomodoro_dep,
    posix_dep,
  ],
  include_directories: config_h_dir,
  install: true,
)
