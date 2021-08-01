#!/usr/bin/env ruby
# -*- coding:utf-8; mode:ruby; -*-

require "revdev"
require "optparse"
require "uinput"

USAGE = <<__EOF
usage:
    $ #{$0} event_device
  display the infomation about event_device.

example:
    $ #{$0} /dev/input/event2

options:
  -g, --grab:
      grab event.
__EOF

def main
  include Revdev

  spec_type = nil
  is_grab = false
  OptionParser.new do |opt|
    opt.on '-g', '--grab' do
      is_grab = true
    end
    opt.parse! ARGV
  end

  if ARGV.length != 1
    puts USAGE
    exit false
  end

  ufile = File.open('/dev/uinput', Fcntl::O_WRONLY | Fcntl::O_NDELAY)

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
  
  file = File.new ARGV.first, 'r+' 
  evdev = EventDevice.new file
  # puts "## Device Name: #{evdev.device_name}"
  puts "spec_type: #{spec_type}" if $DEBUG
  
  c_grab = 1074021776

  destroy = lambda do
    # evdev.ungrab if is_grab
    file.ioctl c_grab, 0 if is_grab
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

  file.ioctl c_grab, 1 if is_grab
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
