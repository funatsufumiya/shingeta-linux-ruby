```
usage:
    $ ruby shingeta.rb -e [event_device] -u [uinput_device] -s [setting_file]
  shingeta keyboard emulator

example:
    $ ruby shingeta.rb -e /dev/input/event2 -u /dev/uinput -s setting.yab

options:
  -e, --event [path]:
      event device (Default: /dev/input/event0)
  -E, --eventsub [path]:
      event sub device (for dual keyboard) (Default: none)
  -u, --uinput [path]:
      uinput device (Default: /dev/uinput)
  -s, --setting [path]:
      setting.yab file (Default: setting.yab)
  -g, --grab [bool]:
      grab event or not. (Default: true)
```