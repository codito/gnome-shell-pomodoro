# Define a common library for all tests.
libtests_common = static_library(
  'tests',
  'common.vala',
  dependencies: libgnome_pomodoro_dep,
  # c_args: [
  #   '-DG_LOG_DOMAIN="Pomodoro"',
  #   '-UG_DISABLE_ASSERT',
    # '-UG_DISABLE_CHECKS',
    # '-UG_DISABLE_CAST_CHECKS',
  # ],
  install: false
)


# Define tests. Each test is a separate executable.
test_names = [
  # 'application',
  # 'capability',
  # 'capability-group',
  # 'capability-manager',
  'time-block',
  'timer',
  # 'timer-view-action-group',
  'timestamp',
  # 'scheduler',
  'session',
  # 'session-manager',
  # 'session-manager-strategy',
  # 'utils',
]

# Compile schemas for unit tests
#compiled_schemas = gnome.compile_schemas(
#  depend_files: meson.current_source_dir() / 'data' / 'org.gnomepomodoro.Pomodoro.gschema.xml'
#)

test_env = environment()
test_env.set('LANGUAGE', 'C')
test_env.set('G_TEST_SRCDIR', meson.current_source_dir())  # TODO: is it used?
test_env.set('G_TEST_BUILDDIR', meson.current_build_dir())  # TODO: is it used?
test_env.set('G_DEBUG', 'gc-friendly')  # ,fatal-criticals
# test_env.set('G_MESSAGES_DEBUG', 'all')
# test_env.set('G_MESSAGES_DEBUG', 'Pomodoro')
# test_env.set('G_ENABLE_DIAGNOSTIC', '1')
test_env.set('GSETTINGS_SCHEMA_DIR', meson.build_root() / 'data')
test_env.set('GSETTINGS_BACKEND', 'memory')
test_env.set('MALLOC_CHECK_', '2')
# test_env.set('GTK_A11Y', 'none')
# test_env.set('NO_AT_BRIDGE', '1')

# if get_option('unit_tests').enabled()
foreach test_name : test_names
  test_sources = ['test-@0@.vala'.format(test_name), compiled_schemas]
  executable_name = 'test-@0@'.format(test_name)
  test(
    test_name,
    executable(
      executable_name,
      test_sources,
      dependencies: libgnome_pomodoro_dep,
      link_with: libtests_common,
      c_args: [
        # '-DG_LOG_DOMAIN="Pomodoro"',
        '-UG_DISABLE_ASSERT',
        # '-UG_DISABLE_CHECKS',
        # '-UG_DISABLE_CAST_CHECKS',
      ],
    ),
    env: test_env,
    suite: 'tests',
  )
endforeach
# endif
