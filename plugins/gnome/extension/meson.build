extension_files = [
  'capabilities.js',
  'dbus.js',
  'dialogs.js',
  'extension.js',
  'indicator.js',
  'notifications.js',
  'presence.js',
  'screenShield.js',
  'stylesheet.css',
  'timer.js',
  'utils.js',
]

install_data(
  extension_files,
  install_dir: extension_dir,
)

install_subdir(
  'icons',
  install_dir: extension_dir,
)

js_conf = configuration_data()

js_conf.set(
  'APPLICATION_ID',
  application_id,
)
js_conf.set(
  'PACKAGE_NAME',
  package_name,
)
js_conf.set(
  'PACKAGE_STRING',
  package_string,
)
js_conf.set(
  'PACKAGE_VERSION',
  package_version,
)
js_conf.set(
  'PACKAGE_BUGREPORT',
  package_bugreport,
)
js_conf.set(
  'PACKAGE_URL',
  package_url,
)
js_conf.set(
  'PACKAGE_LOCALE_DIR',
  package_localedir,
)
js_conf.set(
  'GETTEXT_PACKAGE',
  gettext_package,
)
js_conf.set(
  'GSETTINGS_SCHEMA_DIR',
  gschema_dir,
)
js_conf.set(
  'EXTENSION_UUID',
  extension_uuid,
)

configure_file(
  input: 'metadata.json.in',
  output: 'metadata.json',
  configuration: js_conf,
  install_dir: extension_dir,
)

configure_file(
  input: 'config.js.in',
  output: 'config.js',
  configuration: js_conf,
  install_dir: extension_dir,
)
