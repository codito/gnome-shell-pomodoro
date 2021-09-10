icon_dirs = [
  '16x16',
  '24x24',
  '32x32',
  '48x48',
  '256x256',
  '512x512',
]

hicolor_icondir = get_option('datadir') / 'icons' / 'hicolor'

foreach i:icon_dirs
  install_data(
    i / 'org.gnomepomodoro.Pomodoro.png',
    install_dir: hicolor_icondir / i / 'apps',
  )
endforeach

install_data(
    'symbolic' / 'org.gnomepomodoro.Pomodoro-symbolic.svg',
    install_dir: hicolor_icondir / 'symbolic' / 'apps',
)

