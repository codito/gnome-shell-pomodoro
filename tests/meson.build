# Define a common library for all tests.
libtests = static_library(
  'tests',
  'common.vala',
  dependencies: libgnome_pomodoro_dep,
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
  'timer-view-action-group',
  'session',
  'session-manager',
  # 'utils',
]

# if get_option('unit_tests').enabled()
foreach test_name : test_names
  test_sources = ['test-@0@.vala'.format(test_name)]
  executable_name = 'test-@0@'.format(test_name)
  test(
    test_name,
    executable(
      executable_name,
      test_sources,
      dependencies: libgnome_pomodoro_dep,
      link_with: libtests,
    ),
    env: [
      'LANGUAGE=C',
      'G_TEST_SRCDIR=@0@'.format(meson.current_source_dir()),
      'G_TEST_BUILDDIR=@0@'.format(meson.current_build_dir()),
      'G_MESSAGES_DEBUG=debug',
      'GSETTINGS_SCHEMA_DIR=@0@'.format(meson.build_root() / 'data'),
      'GSETTINGS_BACKEND=memory'
    ],
    suite: 'tests',
  )
endforeach
# endif
