# Resources
resources_sources = files(
  'org.gnomepomodoro.Pomodoro.gresource.xml',
)
resources = gnome.compile_resources(
  'org.gnomepomodoro.Pomodoro',
  resources_sources,
  c_name: 'resources',
)


# Common library
libgnome_pomodoro_sources = files(
  'core/aggregated-entry.vala',
  'core/animation.vala',
  'core/capability-group.vala',
  'core/capability-manager.vala',
  'core/capability.vala',
  'core/cycle.vala',
  'core/database.vala',
  'core/desktop-extension.vala',
  'core/entry.vala',
  'core/presence.vala',
  'core/scheduler.vala',
  'core/session.vala',
  'core/session-entry.vala',
  'core/session-manager.vala',
  'core/session-manager-action-group.vala',
  'core/settings.vala',
  'core/sleep-monitor.vala',
  'core/source.vala',
  'core/state.vala',
  'core/time-block.vala',
  'core/time-block-entry.vala',
  'core/timer.vala',
  'core/timer-action-group.vala',
  'core/timestamp.vala',
  'core/utils.vala',
  'integrations/freedesktop.vala',
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
  'application.vala',
  'main.vala',
  'notifications-capability.vala',
  'service.vala',
  'views/about-window.vala',
  'views/compact-timer-view.vala',
  'views/preferences-window.vala',
  'views/screen-notification.vala',
  'views/stats-day-page.vala',
  'views/stats-month-page.vala',
  'views/stats-page.vala',
  'views/stats-view.vala',
  'views/stats-week-page.vala',
  'views/timer-view.vala',
  'views/window.vala',
  'widgets/accelerator.vala',
  'widgets/gizmo.vala',
  'widgets/log-scale.vala',
  'widgets/monospace-label.vala',
  'widgets/progress-bar.vala',
  'widgets/session-progress-bar.vala',
  'widgets/size-stack.vala',
  'widgets/timer-control-buttons.vala',
  'widgets/timer-label.vala',
  'widgets/timer-progress-bar.vala',
  'widgets/utils.vala',
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
