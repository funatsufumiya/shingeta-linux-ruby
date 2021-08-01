#!/usr/bin/env ruby
# -*- coding:utf-8; mode:ruby; -*-

require "revdev"
require "optparse"

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
  
  file = File.new ARGV.first, 'r+' 
  evdev = EventDevice.new file
  # puts "## Device Name: #{evdev.device_name}"
  puts "spec_type: #{spec_type}" if $DEBUG
  
  c_grab = 1074021776

  on_exit = lambda {
    file.ioctl c_grab, 0 if is_grab
    exit true
  }

  trap :INT do
    puts "# recieve :INT"
    # evdev.ungrab if is_grab
    on_exit.call
  end

  file.ioctl c_grab, 1 if is_grab
  #evdev.grab if is_grab

  is_ctrl = false

  loop do
    ie = evdev.read_input_event
    next if spec_type and spec_type != ie.hr_type.to_s
    t = ie.hr_type ? "#{ie.hr_type.to_s}(#{ie.type})" : ie.type
    c = ie.hr_code ? "#{ie.hr_code.to_s}(#{ie.code})" : ie.code
    v = ie.hr_value ? "#{ie.hr_value.to_s}(#{ie.value})" : ie.value
    #puts "type:#{t}	code:#{c}	value:#{v}"
    if ie.hr_type == :EV_KEY
      
      # if ie.hr_code == 
      if ie.hr_code == :KEY_LEFTCTRL || ie.hr_code == :KEY_RIGHTCTRL
        is_ctrl = ( ie.value == 1 ) 
      elsif ie.hr_code == :KEY_C && ie.value == 1 && is_ctrl
        puts "Ctrl-C pressed!"
        on_exit.call
      else
        puts "type:#{t}	code:#{c}	value:#{v}"
      end
    end
      
  end

end

main
