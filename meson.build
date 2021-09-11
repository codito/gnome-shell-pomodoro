project(
  'gnome-pomodoro',
  ['vala', 'c'],
  version: '0.24.1',
  meson_version: '>=0.58.0',
)

i18n = import('i18n')
gnome = import ('gnome')

glib_dep = dependency('glib-2.0', version: '>=2.38.0')
gobject_dep = dependency('gobject-2.0', version: '>=2.38.0')
gio_dep = dependency('gio-2.0', version: '>=2.38.0')
gtk_dep = dependency('gtk+-3.0', version: '>=3.20.0')
gdk_dep = dependency('gdk-pixbuf-2.0')
cairo_dep = dependency('cairo')
introspection_dep = dependency('gobject-introspection-1.0', version: '>=0.10.1')
peas_dep = dependency('libpeas-1.0', version: '>=1.5.0')
gom_dep = dependency('gom-1.0', version: '>=0.3.0')
gstreamer_dep = dependency('gstreamer-1.0', version: '>=1.0.10')
libcanberra_dep = dependency('libcanberra', version: '>=0.30')
json_dep = dependency('json-glib-1.0', version: '>=1.6.2')
sqlite_dep = dependency('sqlite3')

cc = meson.get_compiler('c')
libm_dep = cc.find_library('m')
valac = meson.get_compiler('vala')
posix_dep = valac.find_library('posix')

add_project_arguments(
  [
    '--vapidir', meson.current_source_dir(),
    '--vapidir', meson.current_source_dir() / 'vapi',
    '--pkg', 'config',
  ],
  language: 'vala',
)

add_project_arguments(
  '-DGETTEXT_PACKAGE="' + meson.project_name() + '"',
  language: 'c',
)

# We are going to use these variables later on for the plugins
gschema_dir = get_option('prefix') / get_option('datadir') / 'glib-2.0' / 'schemas'
plugin_libdir = get_option('prefix') / get_option('libdir') / meson.project_name() / 'plugins'
extension_dir = get_option('prefix') / get_option('datadir') / 'gnome-shell' / 'extensions' / 'pomodoro@gnomepomodoro.org'

# TODO: Remove the double quotes from plugins/indicator/extension/config.js.in.
# Right now we have to set the below config values twice because of that,
# the C/Vala code needs these to be quoted (done via `set_quoted`), but
# config.js.in needs them to be unquoted
package_name = meson.project_name()
package_datadir = get_option('prefix') / get_option('datadir') / meson.project_name()
package_string = package_name + ' ' + meson.project_version()
package_version = meson.project_version()
package_bugreport = 'https://github.com/gnome-pomodoro/gnome-pomodoro/issues'
package_url = 'https://gnomepomodoro.org'
gettext_package = package_name
extension_uuid = 'pomodoro@gnomepomodoro.org'
package_localedir = get_option('prefix') / get_option('datadir') / 'locale'

conf = configuration_data()

conf.set_quoted(
  'GETTEXT_PACKAGE',
  gettext_package,
)
conf.set_quoted(
  'GSETTINGS_SCHEMA_DIR',
  gschema_dir,
)
conf.set_quoted(
  'EXTENSION_UUID',
  extension_uuid,
)
conf.set_quoted(
  'EXTENSION_DIR',
  extension_dir,
)
conf.set_quoted(
  'PACKAGE_LOCALE_DIR',
  package_localedir,
)
conf.set_quoted(
  'PACKAGE_LIB_DIR',
  get_option('prefix') / get_option('libdir') / 'gnome-pomodoro',
)
conf.set_quoted(
  'PACKAGE_DATA_DIR',
  package_datadir,
)
conf.set_quoted(
  'PLUGIN_DATA_DIR',
  package_datadir / 'plugins',
)
conf.set_quoted(
  'PLUGIN_LIB_DIR',
  plugin_libdir,
)
conf.set_quoted(
  'PACKAGE_NAME',
  package_name,
)
conf.set_quoted(
  'PACKAGE_STRING',
  package_string
)
conf.set_quoted(
  'PACKAGE_VERSION',
  package_version,
)
conf.set_quoted(
  'PACKAGE_URL',
  package_url,
)
conf.set_quoted(
  'PACKAGE_BUGREPORT',
  package_bugreport,
)

configure_file(
  output: 'config.h',
  configuration: conf,
)

# Include the config.h we just generated
incs = include_directories('.')

subdir('po')
subdir('data')
subdir('src')
subdir('plugins')
subdir('tests')

meson.add_install_script(
  'meson-post-install.sh',
  get_option('datadir'),
)
