dbus_conf = configuration_data()

dbus_conf.set(
  'bindir',
  get_option('prefix') / get_option('bindir'),
)

configure_file(
  input: 'org.gnomepomodoro.Pomodoro.service.in',
  output: '@BASENAME@',
  configuration: dbus_conf,
  install_dir: get_option('datadir') / 'dbus-1' / 'services',
)

desktop_file = i18n.merge_file(
  input: 'org.gnomepomodoro.Pomodoro.desktop.in',
  output: '@BASENAME@',
  install: true,
  install_dir:  get_option('datadir') / 'applications',
  po_dir: '..' / 'po',
  type: 'desktop',
)

desktop_file_validate = find_program('desktop-file-validate', required:false)
if desktop_file_validate.found()
  test (
    'Validate .desktop',
    desktop_file_validate,
    args: [desktop_file.full_path()]
  )
endif

appdata = i18n.merge_file(
  input: 'org.gnomepomodoro.Pomodoro.appdata.xml.in',
  output: '@BASENAME@',
  install: true,
  install_dir:  get_option('datadir') / 'metainfo',
  po_dir: '..' / 'po',
)

appstream_util = find_program('appstream-util', required: false)

if appstream_util.found()
  test(
    'Validate .appdata.xml',
    appstream_util,
    args: [
      'validate-relax', '--nonet', appdata.full_path()
    ]
  )
endif

install_data(
  'org.gnomepomodoro.Pomodoro.gschema.xml',
  install_dir: gschema_dir,
)

compile_schemas = find_program('glib-compile-schemas', required: false)
if compile_schemas.found()
  test('Validate schema file', compile_schemas,
    args: ['--strict', '--dry-run', meson.current_source_dir()]
  )
endif

compiled_schemas = gnome.compile_schemas(
  depend_files: 'org.gnomepomodoro.Pomodoro.gschema.xml'
)

# compiled_schemas = custom_target(
#   'gschemas.compiled',
#   input: 'org.gnomepomodoro.Pomodoro.gschema.xml',
#   output: 'gschemas.compiled',
#   command: [compile_schemas, meson.current_source_dir()],
#   build_by_default: false
# )


subdir('icons')
subdir('resources')
subdir('sounds')
