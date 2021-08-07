#!/usr/bin/env ruby
# -*- coding:utf-8; mode:ruby; -*-

require "revdev"
require "optparse"
require "uinput"
require "nkf"

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

$yamabuki_key_map = {
  :a => :KEY_A,
  :b => :KEY_B,
  :c => :KEY_C,
  :d => :KEY_D,
  :e => :KEY_E,
  :f => :KEY_F,
  :g => :KEY_G,
  :h => :KEY_H,
  :i => :KEY_I,
  :j => :KEY_J,
  :k => :KEY_K,
  :l => :KEY_L,
  :m => :KEY_M,
  :n => :KEY_N,
  :o => :KEY_O,
  :p => :KEY_P,
  :q => :KEY_Q,
  :r => :KEY_R,
  :s => :KEY_S,
  :t => :KEY_T,
  :u => :KEY_U,
  :v => :KEY_V,
  :w => :KEY_W,
  :x => :KEY_X,
  :y => :KEY_Y,
  :z => :KEY_Z,
  :"0" => :KEY_0,
  :"1" => :KEY_1,
  :"2" => :KEY_2,
  :"3" => :KEY_3,
  :"4" => :KEY_4,
  :"5" => :KEY_5,
  :"6" => :KEY_6,
  :"7" => :KEY_7,
  :"8" => :KEY_8,
  :"9" => :KEY_9,
  :"!" => [:KEY_1],
  :"\"" => [:KEY_2],
  :"#" => [:KEY_3],
  :"$" => [:KEY_4],
  :"%" => [:KEY_5],
  :"&" => [:KEY_6],
  :"'" => [:KEY_7],
  :"(" => [:KEY_8],
  :")" => [:KEY_9],
  :"-" => :KEY_MINUS,
  :"=" => [:KEY_MINUS],
  :"^" => :KEY_EQUAL,
  :"~" => [:KEY_EQUAL],
  :"\\" => :KEY_YEN,
  :"\¥" => :KEY_YEN,
  :"|" => [:KEY_YEN],
  :"@" => :KEY_LEFTBRACE,
  :"`" => [:KEY_LEFTBRACE],
  :"[" => :KEY_RIGHTBRACE,
  :"{" => [:KEY_RIGHTBRACE],
  :";" => :KEY_SEMICOLON,
  :"+" => [:KEY_SEMICOLON],
  :":" => :KEY_APOSTROPHE,
  :"*" => [:KEY_APOSTROPHE],
  :"]" => :KEY_BACKSLASH,
  :"}" => [:KEY_BACKSLASH],
  :"," => :KEY_COMMA,
  :"<" => [:KEY_COMMA],
  :"." => :KEY_DOT,
  :">" => [:KEY_DOT],
  :"/" => :KEY_SLASH,
  :"?" => [:KEY_SLASH],
  :"_" => [:KEY_RO],
  :"後" => :KEY_BACKSPACE,
  :"入" => :KEY_ENTER,
}

$yamabuki_key_str_pos_map = {
  :KEY_1 => [0, 0],
  :KEY_2 => [0, 1],
  :KEY_3 => [0, 2],
  :KEY_4 => [0, 3],
  :KEY_5 => [0, 4],
  :KEY_6 => [0, 5],
  :KEY_7 => [0, 6],
  :KEY_8 => [0, 7],
  :KEY_9 => [0, 8],
  :KEY_0 => [0, 9],
  :KEY_MINUS => [0, 10],
  :KEY_EQUAL => [0, 11],
  :KEY_YEN => [0, 12],
  :KEY_Q => [1, 0],
  :KEY_W => [1, 1],
  :KEY_E => [1, 2],
  :KEY_R => [1, 3],
  :KEY_T => [1, 4],
  :KEY_Y => [1, 5],
  :KEY_U => [1, 6],
  :KEY_I => [1, 7],
  :KEY_O => [1, 8],
  :KEY_P => [1, 9],
  :KEY_LEFTBRACE => [1, 10],
  :KEY_RIGHTBRACE => [1, 11],
  :KEY_A => [2, 0],
  :KEY_S => [2, 1],
  :KEY_D => [2, 2],
  :KEY_F => [2, 3],
  :KEY_G => [2, 4],
  :KEY_H => [2, 5],
  :KEY_J => [2, 6],
  :KEY_K => [2, 7],
  :KEY_L => [2, 8],
  :KEY_SEMICOLON => [2, 9],
  :KEY_APOSTROPHE => [2, 10],
  :KEY_BACKSLASH => [2, 11],
  :KEY_Z => [3, 0],
  :KEY_X => [3, 1],
  :KEY_C => [3, 2],
  :KEY_V => [3, 3],
  :KEY_B => [3, 4],
  :KEY_N => [3, 5],
  :KEY_M => [3, 6],
  :KEY_COMMA => [3, 7],
  :KEY_DOT => [3, 8],
  :KEY_SLASH => [3, 9],
  :KEY_RO => [3, 10],
}

def get_yamabuki_key_str_pos(hr_code)
  $yamabuki_key_str_pos_map[hr_code]
end

def get_yamabuki_key_str(ie, fn_mode, fn_mode_type, yamabuki_setting)
  pos = get_yamabuki_key_str_pos(ie.hr_code)
  if pos.nil?
    nil
  else
    yamabuki_setting[fn_mode][fn_mode_type][pos[0]][pos[1]]
  end
end

def zen_to_han(s)
  NKF.nkf('-w -Z4 -x', s)
end

def get_revdev_code(hr_code)
  Revdev::REVERSE_MAPS[:KEY].key hr_code
end

def prosess_yamabuki_key(ie, fn_mode, fn_mode_type, yamabuki_setting)
  has_processed = false

  key_str = get_yamabuki_key_str(ie, fn_mode, fn_mode_type, yamabuki_setting)
  unless key_str.nil?
    key_list = key_str.chars

    p key_list

    key_list.each do |key|
      # p key
      s0 = zen_to_han(key)
      # p s0
      hr_code = $yamabuki_key_map[s0.to_sym]

      # p hr_code
      unless hr_code.nil?
        is_shift_internal = false

        if hr_code.instance_of?(Array)
          is_shift_internal = true
          hr_code = hr_code[0]
        end

        code = get_revdev_code(hr_code)

        unless code.nil?
          # p code

          press_shift if is_shift_internal
          
          ie.code = code
          uinput_write_input ie

          release_shift if is_shift_internal

          has_processed = true
        end
      end
    end
  end

  return has_processed
end

def prosess_key(ie, is_ctrl, is_left_shift, is_right_shift, is_left_oya_shift, is_right_oya_shift, is_alt, is_kana, yamabuki_setting)
  if is_ctrl
    return false
  else
    is_shift = is_left_shift or is_right_shift

    fn_mode_type = :NO_SHIFT
    if is_shift and !(is_left_oya_shift or is_right_oya_shift)
      fn_mode_type = :SHIFT
    elsif is_left_oya_shift
      fn_mode_type = :LEFT_OYA_SHIFT
    elsif is_right_oya_shift
      fn_mode_type = :RIGHT_OYA_SHIFT
    end

    fn_mode = is_kana ? :ROMAJI : :EISU

    return prosess_yamabuki_key(ie, fn_mode, fn_mode_type, yamabuki_setting)
  end

  false
end

$uinput_file = nil

def uinput_write_input(ie)
  event = LinuxInput::InputEvent.new
  event[:time] = LinuxInput::Timeval.new
  event[:time][:tv_sec] = Time.now.to_i
  event[:type] = ie.type
  event[:code] = ie.code
  event[:value] = ie.value
  $uinput_file.syswrite(event.pointer.read_bytes(event.size))
end

def uinput_write(type, code, value)
  event = LinuxInput::InputEvent.new
  event[:time] = LinuxInput::Timeval.new
  event[:time][:tv_sec] = Time.now.to_i
  event[:type] = type
  event[:code] = code
  event[:value] = value
  $uinput_file.syswrite(event.pointer.read_bytes(event.size))
end

def press_shift()
  uinput_write(Revdev::EV_KEY, Revdev::KEY_LEFTSHIFT, 1)
  uinput_write(Revdev::EV_SYN, Revdev::SYN_REPORT, 0)
  uinput_write(Revdev::EV_MSC, Revdev::MSC_SCAN, 11)
end

def release_shift()
  uinput_write(Revdev::EV_KEY, Revdev::KEY_LEFTSHIFT, 0)
  uinput_write(Revdev::EV_SYN, Revdev::SYN_REPORT, 0)
  uinput_write(Revdev::EV_MSC, Revdev::MSC_SCAN, 11)
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

  destroy = lambda do |arg|
    # evdev.ungrab if is_grab
    efile.ioctl c_grab, 0 if is_grab
    puts "ungrab" if is_grab

    ufile.ioctl(Uinput::UI_DEV_DESTROY, nil)
    puts "destroy"

    exit true
  end

  trap :INT, &destroy
  trap :TERM, &destroy

  $uinput_file = ufile

  # uinput_write_input_event = lambda do |ie|
  #   event = LinuxInput::InputEvent.new
  #   event[:time] = LinuxInput::Timeval.new
  #   event[:time][:tv_sec] = Time.now.to_i
  #   event[:type] = ie.type
  #   event[:code] = ie.code
  #   event[:value] = ie.value
  #   ufile.syswrite(event.pointer.read_bytes(event.size))
  # end

  efile.ioctl c_grab, 1 if is_grab
  #evdev.grab if is_grab

  is_ctrl = false
  is_left_shift = false
  is_right_shift = false
  is_left_oya_shift = false
  is_right_oya_shift = false
  is_alt = false
  
  # is_kana = false
  is_kana = true

  loop do
    ie = evdev.read_input_event
    t = ie.hr_type ? "#{ie.hr_type.to_s}(#{ie.type})" : ie.type
    c = ie.hr_code ? "#{ie.hr_code.to_s}(#{ie.code})" : ie.code
    v = ie.hr_value ? "#{ie.hr_value.to_s}(#{ie.value})" : ie.value
    #puts "type:#{t}	code:#{c}	value:#{v}"

    if ie.hr_type == :EV_KEY

      has_processed_key_flag = false
      
      # if ie.hr_code == 
      if ie.hr_code == :KEY_LEFTCTRL or ie.hr_code == :KEY_RIGHTCTRL
        is_ctrl = ( ie.value == 1 )
      elsif ie.hr_code == :KEY_LEFTSHIFT
        is_left_shift = ( ie.value == 1 )
        has_processed_key_flag = true
      elsif ie.hr_code == :KEY_RIGHTSHIFT
        is_right_shift = ( ie.value == 1 )
        has_processed_key_flag = true
      elsif ie.hr_code == :KEY_MUHENKAN
        is_left_oya_shift = ( ie.value == 1 )
        has_processed_key_flag = true
      elsif ie.hr_code == :KEY_HENKAN
        is_right_oya_shift = ( ie.value == 1 )
        has_processed_key_flag = true
      elsif ie.hr_code == :KEY_LEFTALT or ie.hr_code == :KEY_RIGHTALT
        is_alt = ( ie.value == 1 )
      else
        has_processed_key_flag = prosess_key(ie, is_ctrl, is_left_shift, is_right_shift, is_left_oya_shift, is_right_oya_shift, is_alt, is_kana, yamabuki_setting)
        # puts "type:#{t}	code:#{c}	value:#{v}"
      end

      if ie.hr_code == :KEY_C and ie.value == 1 and is_ctrl and is_alt and (is_left_shift or is_right_shift)
        puts "Ctrl-Alt-Shift-C pressed!"
        destroy.call
        has_processed_key_flag = false
      end

      if has_processed_key_flag == false
        uinput_write_input ie
      end

    else
      uinput_write_input ie
    end

    # uinput_write_input_event.call ie
    # puts "type:#{t}	code:#{c}	value:#{v}"

  end

end

main
