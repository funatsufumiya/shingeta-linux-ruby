## shingeta-linux-ruby

Ubuntu/Debian上で利用できるキーボードエミュレータで、やまぶきRと同じシンタックスをサポートすることを目標にしています。
現在はまず新下駄配列とProgrommer's Dvorakを動作させることを目標にしていて、まだアーリーステージですが実際に使用することができます。

## Usage
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

## TODOs

- 同時打鍵判定の改善
- 日本語入力システムとの連携 （現在は単に特定キーで切り替え）
- GUIの整備
- 自動起動などのサービス化
- Rust実装など、軽量化
