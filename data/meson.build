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
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas',
)

subdir('icons')
subdir('resources')
subdir('sounds')
