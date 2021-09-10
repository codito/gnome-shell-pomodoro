libaction_vala_sources = [
  'action-listboxrow.vala',
  'action-page.vala',
  'actions.vala',
  'action.vala',
  'enums.vala',
  'preferences-page.vala',
]

generated_sources = gnome.compile_resources(
  'plugins-actions-resources',
  'resources/resources.xml',
  c_name: 'pomodoro',
  source_dir: 'resources',
)

shared_library(
  'actions',
  [libaction_vala_sources, generated_sources],
  dependencies: gnome_pomodoro_lib_dep,
  install: true,
  install_dir: plugin_libdir,
)

install_data(
  'actions.plugin',
  install_dir: plugin_libdir,
)

install_data(
  'org.gnomepomodoro.Pomodoro.plugins.actions.gschema.xml',
  install_dir: gschema_dir,
)
