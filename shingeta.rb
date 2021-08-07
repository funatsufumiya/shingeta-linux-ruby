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
        fn_mode = :ROMAJI # FIXME
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
  :A => [:KEY_A],
  :B => [:KEY_B],
  :C => [:KEY_C],
  :D => [:KEY_D],
  :E => [:KEY_E],
  :F => [:KEY_F],
  :G => [:KEY_G],
  :H => [:KEY_H],
  :I => [:KEY_I],
  :J => [:KEY_J],
  :K => [:KEY_K],
  :L => [:KEY_L],
  :M => [:KEY_M],
  :N => [:KEY_N],
  :O => [:KEY_O],
  :P => [:KEY_P],
  :Q => [:KEY_Q],
  :R => [:KEY_R],
  :S => [:KEY_S],
  :T => [:KEY_T],
  :U => [:KEY_U],
  :V => [:KEY_V],
  :W => [:KEY_W],
  :X => [:KEY_X],
  :Y => [:KEY_Y],
  :Z => [:KEY_Z],
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
  :"無" => :NOTHING,
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

def get_yamabuki_key_str(ie, holding_key_code, fn_mode, fn_mode_type, yamabuki_setting)
  if ie.hr_code != holding_key_code
    if holding_key_code and fn_mode == :ROMAJI
      pos = get_yamabuki_key_str_pos(ie.hr_code)
      layer = $yamabuki_key_map.key holding_key_code

      # print "layer = "
      # p layer
      # p holding_key_code

      unless layer.nil? and pos.nil?
        if yamabuki_setting[fn_mode][layer]
          key_str = yamabuki_setting[fn_mode][layer][pos[0]][pos[1]]
          return key_str if (not key_str.nil? and key_str != "無")
        end
      end

      # NOTE: Check Inverted Layer
      pos = get_yamabuki_key_str_pos(holding_key_code)
      layer = $yamabuki_key_map.key ie.hr_code

      unless layer.nil? and pos.nil?
        if yamabuki_setting[fn_mode][layer]
          key_str = yamabuki_setting[fn_mode][layer][pos[0]][pos[1]]
          return key_str if (not key_str.nil? and key_str != "無")
        end
      end
    end
  end

  pos = get_yamabuki_key_str_pos(ie.hr_code)
  if pos.nil?
    nil
  else
    ss = yamabuki_setting[fn_mode][fn_mode_type]
    return ss[pos[0]][pos[1]] if (not ss.nil?)
    nil
  end
end

def zen_to_han(s)
  NKF.nkf('-w -Z4 -x', s)
end

def get_revdev_code(hr_code)
  Revdev::REVERSE_MAPS[:KEY].key hr_code
end

def process_yamabuki_key(ie, holding_key_code, fn_mode, fn_mode_type, yamabuki_setting)
  has_processed = false

  # unless prev_ie.nil?
  #   p prev_ie.hr_code
  # end

  key_str = get_yamabuki_key_str(ie, holding_key_code, fn_mode, fn_mode_type, yamabuki_setting)

  unless key_str.nil?
    key_list = key_str.chars

    p key_list if $is_debug_verbose

    key_list.each do |key|
      if key == "無"
        # puts "got mu"
        has_processed = true
        next
      end
      # p key
      s0 = zen_to_han(key)
      #p s0
      hr_code = $yamabuki_key_map[s0.to_sym]
      #p hr_code if $is_debug_verbose

      unless hr_code.nil?
        is_shift_internal = false

        if hr_code.instance_of?(Array)
          is_shift_internal = true
          hr_code = hr_code[0]
	end

	# if fn_mode == :EISU and fn_mode_type == :SHIFT
	#  is_shift_internal = true
	# end

        code = get_revdev_code(hr_code)

        unless code.nil?
          # p code

          press_shift if is_shift_internal
          
          if fn_mode == :ROMAJI
            current_key_code = ie.code
            # current_key_hrcode = ie.hr_code
            current_key_state = ie.value

            ie.code = code
            # if current_key_hrcode == holding_key_code and current_key_state == 0
              ie.value = 1
              uinput_write_input ie
              ie.value = 0
              uinput_write_input ie
              ie.value = current_key_state
            # else
              # uinput_write_input ie
            # end

            ie.code = current_key_code
          else
            current_key_code = ie.code
            ie.code = code
            uinput_write_input ie
            ie.code = current_key_code
          end

          release_shift if is_shift_internal

          has_processed = true
        end
      end
    end
  end

  return has_processed
end

def process_key(ie, holding_key_code, is_ctrl, is_left_shift, is_right_shift, is_left_oya_shift, is_right_oya_shift, is_alt, is_kana, yamabuki_setting)
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

    return process_yamabuki_key(ie, holding_key_code, fn_mode, fn_mode_type, yamabuki_setting)
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

def copy_ie(ie)
  event = Revdev::InputEvent.new
  # event[:time] = LinuxInput::Timeval.new # FIXME
  # event[:time][:tv_sec] = Time.now.to_i # FIXME
  event.type = ie.type
  event.code = ie.code
  event.value = ie.value
  return event
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
  verbose_flag = false
  debug_flag = false
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
    opt.on '-v', '--verbose' do
      verbose_flag = true
    end
    opt.on '-d', '--debug' do
      debug_flag = true
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

  $is_debug = debug_flag
  $is_debug_verbose = verbose_flag
  
  is_kana = false
  # is_kana = true

  holding_check_span = 0.14

  holding_key_code = nil
  holding_started_time = Time.now - 9999
  holding_ended_time = nil
  holding_combination_has_processed = false

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
      elsif ie.hr_code == :KEY_BACKSPACE
        has_processed_key_flag = false
      elsif ie.hr_code == :KEY_SPACE
        if is_ctrl and ie.value == 1 
          is_kana = (not is_kana)
          puts "kana: #{is_kana}"
        end

        has_processed_key_flag = false
      elsif ie.hr_code == :KEY_ESC
        has_processed_key_flag = false
      elsif ie.hr_code == :KEY_CAPSLOCK
        has_processed_key_flag = false
      elsif ie.hr_code == :KEY_ENTER
        has_processed_key_flag = false
      elsif ie.hr_code == :KEY_LEFT or ie.hr_code == :KEY_RIGHT or ie.hr_code == :KEY_DOWN or ie.hr_code == :KEY_UP or ie.hr_code == :KEY_TAB
        has_processed_key_flag = false
      elsif ie.hr_code == :KEY_LEFTALT or ie.hr_code == :KEY_RIGHTALT
        is_alt = ( ie.value == 1 )
      else

        # if ie.hr_code == :KEY_SPACE and ie.value == 1 and is_ctrl
        #   is_kana = (not is_kana)
        #   puts "kana: #{is_kana}"
        # end

        if ie.hr_code == :KEY_M and ie.value == 1 and is_ctrl and is_alt and (is_left_shift or is_right_shift)
          is_kana = (not is_kana)
          puts "kana: #{is_kana}"
        end

        if ie.hr_code == :KEY_C and ie.value == 1 and is_ctrl and is_alt and (is_left_shift or is_right_shift)
          puts "Ctrl-Alt-Shift-C pressed!"
          destroy.call
          has_processed_key_flag = false
        end

        if is_kana
          current_key_code = ie.hr_code
          current_key_state = ie.value

          if (not holding_key_code.nil?) and (not holding_ended_time.nil?)
            if Time.now - holding_started_time > holding_check_span
              puts "( holding ended )" if $is_debug_verbose
              has_processed_key_flag = true
              holding_key_code = nil
              holding_started_time = nil
              holding_ended_time = nil
              holding_combination_has_processed = false
              next
            else
              if $is_debug_verbose
                print "( holding time = "
                print Time.now - holding_started_time
                print " )"
                puts
              end
            end
          end

          if current_key_state == 1 and (not holding_key_code)
            holding_key_code = nil
            holding_started_time = nil
            holding_ended_time = nil
            holding_combination_has_processed = false

            holding_key_code = ie.hr_code
            holding_started_time = Time.now

            if $is_debug_verbose
              print "( holding started "
              print holding_key_code
              print " )"
              puts
            end

            next
          end

          # if current_key_state == 0 or ( current_key_state == 1 and (not holding_combination_has_processed) )
          
          _holding_key_code = (not holding_combination_has_processed) ? holding_key_code : nil

          unless holding_key_code.nil?
            if $is_debug_verbose
              print "holding = "
              print holding_key_code
              if holding_combination_has_processed
                print " (processed)"
              end
              print ", "
            end
          end

          if $is_debug_verbose
            print "key_code = "
            print current_key_code
            print " ( state = "
            print current_key_state
            print " )"
            puts
          end

          if holding_combination_has_processed and (not holding_key_code.nil?) and current_key_code == holding_key_code and current_key_state == 0
            if Time.now - holding_started_time > holding_check_span
              if $is_debug_verbose
                print "( holding time = "
                print Time.now - holding_started_time
                print " )"
                puts
                puts "( holding ended )"
              end
              has_processed_key_flag = true
              holding_key_code = nil
              holding_started_time = nil
              holding_ended_time = nil
              holding_combination_has_processed = false
              next
            else
              holding_ended_time = Time.now if holding_ended_time.nil?
              puts "( holding WILL end )" if $is_debug_verbose
              next
            end
          end

          if holding_combination_has_processed and current_key_code != holding_key_code and current_key_state == 0
            puts "( holding already processed. ignored. )" if $is_debug_verbose
            next
          end

          # ===
          has_processed_key_flag = process_key(ie, _holding_key_code, is_ctrl, is_left_shift, is_right_shift, is_left_oya_shift, is_right_oya_shift, is_alt, is_kana, yamabuki_setting)
          # ===


          if has_processed_key_flag and (not holding_combination_has_processed) and current_key_code != holding_key_code
            holding_combination_has_processed = true
            puts "( holding combination processed )" if $is_debug_verbose
          end

          if (not holding_key_code.nil?) and current_key_code == holding_key_code and current_key_state == 0
            if Time.now - holding_started_time > holding_check_span
              has_processed_key_flag = true
              holding_key_code = nil
              holding_started_time = nil
              holding_ended_time = nil
              holding_combination_has_processed = false
              puts "( holding ended )" if $is_debug_verbose
              next
            else
              holding_ended_time = Time.now if holding_ended_time.nil?
              puts "( holding WILL end )" if $is_debug_verbose
            end
          end

        else
          has_processed_key_flag = process_key(ie, nil, is_ctrl, is_left_shift, is_right_shift, is_left_oya_shift, is_right_oya_shift, is_alt, is_kana, yamabuki_setting)
        end

        # puts "type:#{t}	code:#{c}	value:#{v}"
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
