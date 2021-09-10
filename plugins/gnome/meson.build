libgnome_vala_sources = [
  'gnome.vala',
  'gnome-idle-monitor.vala',
  'gnome-plugin.vala',
  'gnome-shell-extension.vala',
]

shared_library(
  'gnome',
  libgnome_vala_sources,
  dependencies: [
    gnome_pomodoro_lib_dep,
    json_dep,
  ],
  install: true,
  install_dir: plugin_libdir,
)

install_data(
  'gnome.plugin',
  install_dir: plugin_libdir,
)

install_data(
  'org.gnomepomodoro.Pomodoro.plugins.gnome.gschema.xml',
  install_dir: gschema_dir,
)

subdir('extension')
