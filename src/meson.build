# Common library
libgnome_pomodoro_sources = files(
  'aggregated-entry.vala',
  'animation.vala',
  'capability-group.vala',
  'capability-manager.vala',
  'capability.vala',
  'database.vala',
  'desktop-extension.vala',
  'entry.vala',
  'freedesktop.vala',
  'presence.vala',
  'scheduler.vala',
  'session.vala',
  'session-entry.vala',
  'session-manager.vala',
  'settings.vala',
  'sleep-monitor.vala',
  'source.vala',
  'state.vala',
  'time-block.vala',
  'time-block-entry.vala',
  'timeline.vala',
  'timer.vala',
  'timestamp.vala',
  'utils.vala',
)

libgnome_pomodoro = static_library(
  'gnome-pomodoro',
  libgnome_pomodoro_sources,
  dependencies: [
    gio_dep,
    gobject_dep,
    gom_dep,
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
    gom_dep,
    gtk_dep,
    cairo_dep,
    graphene_dep,
    libadwaita_dep,
    peas_dep,
  ],
  include_directories: [
    # Include gnome-pomodoro.h
    include_directories('.'),
  ],
)


# The gnome-pomodoro binary
gnome_pomodoro_vala_sources = files(
  'about-window.vala',
  'accelerator.vala',
  'application.vala',
  'compact-timer-view.vala',
  'gizmo.vala',
  'log-scale.vala',
  'main.vala',
  'monospace-label.vala',
  'preferences-dialog.vala',
  'progress-bar.vala',
  'screen-notification.vala',
  'session-manager-action-group.vala',
  'session-progress-bar.vala',
  'size-stack.vala',
  'stats-day-page.vala',
  'stats-month-page.vala',
  'stats-page.vala',
  'stats-view.vala',
  'stats-week-page.vala',
  'timer-action-group.vala',
  'timer-control-buttons.vala',
  'timer-label.vala',
  'timer-progress-bar.vala',
  'timer-view.vala',
  'utils-ui.vala',
  'window.vala',
  'notifications-capability.vala',  # TODO: move it to lib?
  'service.vala',  # TODO: move it to lib?
)
gnome_pomodoro_sources = [
  gnome_pomodoro_vala_sources,
  resources,
]

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
