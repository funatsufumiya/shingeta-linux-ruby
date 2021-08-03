#!/usr/bin/env ruby
# -*- coding:utf-8; mode:ruby; -*-

require "revdev"
require "optparse"
require "uinput"

USAGE = <<__EOF
usage:
    $ #{$0} -e [event_device] -u [uinput_device] -s [setting_file]
  shingeta keyboard emulator

example:
    $ #{$0} -e /dev/input/event2 -u /dev/uinput -s setting.yab

options:
  -e, --event [path]:
      event device (Default: /dev/input/event0)
  -u, --uinput [path]:
      uinput device (Default: /dev/uinput)
  -s, --setting [path]:
      setting.yab file (Default: setting.yab)
  -g, --grab [bool]:
      grab event or not. (Default: true)
__EOF


$valid_letters = "ぁあぃいぅうぇえぉおかがきぎくぐけげこごさざしじすずせぜそぞただちぢっつづてでとどなにぬねのはばぱひびぴふぶぷへべぺほぼぽまみむめもゃやゅゆょよらりるれろわをんヴ、。゛゜「」ー・
！”＃＄％＆’（）＊＋，－．／０１２３４５６７８９：；＜＝＞？＠ＡＢＣＤＥＦＧＨＩＪＫＬＭＮＯＰＱＲＳＴＵＶＷＸＹＺ［￥］＾＿｀‘ａｂｃｄｅｆｇｈｉｊｋｌｍｎｏｐｑｒｓｔｕｖｗｘｙｚ｛｜｝～
逃入空後消挿上左右下家終前次無"

def parse_yamabuki_line line, line_num
  lst = []
  s = line
  n = s.length
  i = 0
  while i < n
    if s[i] == "'" and s[i+2] == "'" and (s[i+3] == ',' or s[i+3] == nil)
      lst.push (s[i+1])
      i += 4
    elsif $valid_letters.include?(s[i]) and (s[i+1] == ',' or s[i+1] == nil)
      lst.push s[i]
      i += 2
    elsif $valid_letters.include?(s[i]) and $valid_letters.include?(s[i+1])
      _s = s[i]
      _i = i + 1
      while true
        if $valid_letters.include?(s[_i])
          _s += s[_i]
          _i += 1
        elsif s[_i] == ',' or s[_i] == nil
          _i += 1
          break
        else
          STDERR.puts "Yamabuki Setting Parse Error: line #{line_num+1}, col #{_i+1}"
          exit 1
        end
      end
      lst.push _s
      i += (_i - i)
    else
      # p lst
      # p s[i]
      # p s[i+1]
      STDERR.puts "Yamabuki Setting Parse Error: line #{line_num+1}, col #{i+1}"
      exit 1
    end
  end

  lst
end

def parse_yamabuki_setting lst
  romaji_maps =
    {"ローマ字シフト無し" => :NO_SHIFT,
    "ローマ字左親指シフト" => :LEFT_OYA_SHIFT,
    "ローマ字右親指シフト" => :RIGHT_OYA_SHIFT,
    "ローマ字小指シフト" => :SHIFT}
  romaji_labels = romaji_maps.keys

  eisu_maps =
    {"英数シフト無し" => :NO_SHIFT,
    "英数左親指シフト" => :LEFT_OYA_SHIFT,
    "英数右親指シフト" => :RIGHT_OYA_SHIFT,
    "英数小指シフト" => :SHIFT}
  eisu_labels = eisu_maps.keys

  result = {}
  fn_mode = nil
  fn_mode_type = nil
  fn_line_num = 0
  fn_lst = []
  key_label = ""

  lst.each_with_index do |s, i|
    if s == "" or s.start_with? ";"
      next
    end

    if fn_mode != nil and fn_line_num > 3
      if result[fn_mode].nil?
        result[fn_mode] = {}
      end
      result[fn_mode][fn_mode_type] = fn_lst
      fn_lst = []
      fn_mode = nil
    end

    if fn_mode == nil
      if m = s.match(/^\[(.*)\]$/)
        lbl = m[1]
        if romaji_labels.include?(lbl)
          fn_mode = :ROMAJI
          fn_mode_type = romaji_maps[lbl]
        elsif eisu_labels.include?(lbl)
          fn_mode = :EISU
          fn_mode_type = eisu_maps[lbl]
        else
          STDERR.puts "Yamabuki Setting Parse Error: line #{i+1}"
          exit 1
        end

        fn_line_num = 0
      elsif m = s.match(/^<(.)>$/) # FIXME
        lbl = m[1]
        fn_mode = :ROMAJI
        fn_mode_type = lbl.to_sym
        fn_line_num = 0
      else
        STDERR.puts "Yamabuki Setting Parse Error: line #{i+1}"
        exit 1
      end
    else
      fn_lst.push (parse_yamabuki_line s, fn_line_num + i)
      fn_line_num += 1
    end

    # puts s
  end

  if fn_mode != nil and fn_line_num > 3
    if result[fn_mode].nil?
      result[fn_mode] = {}
    end
    result[fn_mode][fn_mode_type] = fn_lst
    fn_lst = []
    fn_mode = nil
  end

  result
end

def main
  include Revdev

  event_device_path = '/dev/input/event0'
  uinput_device_path = '/dev/uinput'
  setting_path = 'setting.yab'
  is_grab = true
  OptionParser.new do |opt|
    opt.on '-e PATH', '--event PATH', String do |s|
      event_device_path = s
    end
    opt.on '-u PATH', '--uinput PATH', String do |s|
      uinput_device_path = s
    end
    opt.on '-s PATH', '--setting PATH', String do |s|
      setting_path = s
    end
    opt.on '-g BOOL', '--grab BOOL', String do |s|
      is_grab = ['1', 'true', 'yes', 'on'].include?(s.to_s.downcase)
    end
    opt.on '-h', '--help' do
      puts USAGE
      exit false
    end
    opt.parse! ARGV
  end

  # if ARGV.length != 1
  #   puts USAGE
  #   exit false
  # end

  lst = []
  File.open(setting_path) do |file|
    lst = file.read.split("\n")
  end

  yamabuki_setting = parse_yamabuki_setting(lst)

  ufile = File.open(uinput_device_path, Fcntl::O_WRONLY | Fcntl::O_NDELAY)

  device = Uinput::UinputUserDev.new
  device[:name] = "Virtual Ruby Device"
  #device[:id][:type] = LinuxInput::BUS_VIRTUAL
  device[:id][:vendor] = 0
  device[:id][:product] = 0
  device[:id][:version] = 0


  for i in 0..126
    ufile.ioctl(Uinput::UI_SET_KEYBIT, i)
  end

  ufile.ioctl(Uinput::UI_SET_EVBIT, Revdev::EV_KEY)
  ufile.ioctl(Uinput::UI_SET_EVBIT, Revdev::EV_SYN)

  ufile.syswrite(device.pointer.read_bytes(device.size))
  ufile.ioctl(Uinput::UI_DEV_CREATE)
  
  efile = File.new event_device_path, 'r+' 
  evdev = EventDevice.new efile
  # puts "## Device Name: #{evdev.device_name}"
  puts "spec_type: #{spec_type}" if $DEBUG
  
  c_grab = 1074021776

  destroy = lambda do
    # evdev.ungrab if is_grab
    efile.ioctl c_grab, 0 if is_grab
    puts "ungrab" if is_grab

    ufile.ioctl(Uinput::UI_DEV_DESTROY, nil)
    puts "destroy"

    exit true
  end

  trap :INT, &destroy
  trap :TERM, &destroy

  uinput_write_input_event = lambda do |ie|
    event = LinuxInput::InputEvent.new
    event[:time] = LinuxInput::Timeval.new
    event[:time][:tv_sec] = Time.now.to_i
    event[:type] = ie.type
    event[:code] = ie.code
    event[:value] = ie.value
    ufile.syswrite(event.pointer.read_bytes(event.size))
  end

  efile.ioctl c_grab, 1 if is_grab
  #evdev.grab if is_grab

  is_ctrl = false

  loop do
    ie = evdev.read_input_event
    t = ie.hr_type ? "#{ie.hr_type.to_s}(#{ie.type})" : ie.type
    c = ie.hr_code ? "#{ie.hr_code.to_s}(#{ie.code})" : ie.code
    v = ie.hr_value ? "#{ie.hr_value.to_s}(#{ie.value})" : ie.value
    #puts "type:#{t}	code:#{c}	value:#{v}"

    # if 30 <= ie.code and ie.code <= 56
      uinput_write_input_event.call ie
      puts "type:#{t}	code:#{c}	value:#{v}"
    # end

    if ie.hr_type == :EV_KEY
      
      # if ie.hr_code == 
      if ie.hr_code == :KEY_LEFTCTRL or ie.hr_code == :KEY_RIGHTCTRL
        is_ctrl = ( ie.value == 1 ) 
      elsif ie.hr_code == :KEY_C and ie.value == 1 and is_ctrl
        puts "Ctrl-C pressed!"
        destroy.call
      else
        if 30 <= ie.code and ie.code <= 56
          uinput_write_input_event.call ie
        end
        # puts "type:#{t}	code:#{c}	value:#{v}"
      end

    end

  end

end

main
