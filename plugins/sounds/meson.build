libsound_vala_sources = [
  'sound-player.vala',
  'sounds-plugin.vala',
]

generated_sources = gnome.compile_resources(
  'plugins-sounds-resources',
  'resources/resources.xml',
  c_name: 'pomodoro',
  source_dir: 'resources',
)

shared_library(
  'sounds',
  [libsound_vala_sources, generated_sources],
  dependencies: [
    gnome_pomodoro_lib_dep,
    gstreamer_dep,
    libcanberra_dep,
    libm_dep,
  ],
  install: true,
  install_dir: plugin_libdir,
)

install_data(
  'sounds.plugin',
  install_dir: plugin_libdir,
)

install_data(
  'org.gnomepomodoro.Pomodoro.plugins.sounds.gschema.xml',
  install_dir: gschema_dir,
)
