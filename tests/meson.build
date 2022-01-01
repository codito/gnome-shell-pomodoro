libtests = static_library(
  'tests',
  'common.vala',
  dependencies: libgnome_pomodoro_dep,
)

test_names = [
  # 'application',
  # 'capability',
  # 'capability-group',
  # 'capability-manager',
  'time-block',
  'timer',
  'session',
  'session-manager',
  # 'utils',
]

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
      'G_TEST_SRCDIR=@0@'.format(meson.current_source_dir()),
      'G_TEST_BUILDDIR=@0@'.format(meson.current_build_dir()),
      'G_MESSAGES_DEBUG=all',
    ],
    suite: 'tests',
  )
endforeach

