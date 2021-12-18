# gnome_pomodoro_test_vala_sources = [
#   'tests.vala',
#   'test-application.vala',
#   'test-capability.vala',
#   'test-capability-group.vala',
#   'test-capability-manager.vala',
#   'test-time-block.vala',
#   'test-timer.vala',
# ]

# test_executable = executable(
#   'gnome-pomodoro-test-executable',
#   gnome_pomodoro_test_vala_sources,
#   dependencies: gnome_pomodoro_lib_dep,
# )

# test(
#   'gnome-pomodoro-tests',
#   test_executable,
# )


tests_lib_static = static_library(
  'tests',
  'tests.vala',
  dependencies: gnome_pomodoro_lib_dep,
)

test(
  'test-time-block',
  executable(
    'test-time-block-executable',
    'test-time-block.vala',
    dependencies: gnome_pomodoro_lib_dep,
    link_with: tests_lib_static,
  )
)


