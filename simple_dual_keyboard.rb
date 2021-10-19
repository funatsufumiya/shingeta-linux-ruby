#!/usr/bin/env ruby
# -*- coding:utf-8; mode:ruby; -*-

require "revdev"
require "optparse"
require "uinput"

USAGE = <<__EOF
usage:
    $ #{$0} -e [event_device] -E [event_device_sub] -u [uinput_device]
  simple dual keyboard pass through to uinput

example:
    $ #{$0} -e /dev/input/event3 -E /dev/input/event16 -u /dev/uinput

options:
  -e, --event [path]:
      event device (Default: /dev/input/event0)
  -E, --eventsub [path]:
      event sub device (for dual keyboard) (Default: none)
  -u, --uinput [path]:
      uinput device (Default: /dev/uinput)
  -g, --grab [bool]:
      grab event or not. (Default: true)
__EOF

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
  event_device_sub_path = nil
  uinput_device_path = '/dev/uinput'
  is_grab = true
  verbose_flag = false
  debug_flag = false
  OptionParser.new do |opt|
    opt.on '-e PATH', '--event PATH', String do |s|
      event_device_path = s
    end
    opt.on '-E PATH', '--eventsub PATH', String do |s|
      event_device_sub_path = s
    end
    opt.on '-u PATH', '--uinput PATH', String do |s|
      uinput_device_path = s
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

  efile_sub = nil
  evdev_sub = nil

  if event_device_sub_path
    efile_sub = File.new event_device_sub_path, 'r+' 
    evdev_sub = EventDevice.new efile_sub
  end

  is_exitting = false

  # puts "## Device Name: #{evdev.device_name}"
  puts "spec_type: #{spec_type}" if $DEBUG

  c_grab = 1074021776

  destroy = lambda do |arg|
    is_exitting = true
    if is_grab
      efile.ioctl c_grab, 0
      efile_sub.ioctl c_grab, 0 if efile_sub
      puts "ungrabbed"
    end

    ufile.ioctl(Uinput::UI_DEV_DESTROY, nil)
    puts "destroyed"

    exit true
  end

  trap :INT, &destroy
  trap :TERM, &destroy

  $uinput_file = ufile

  if is_grab
    efile.ioctl c_grab, 1
    efile_sub.ioctl c_grab, 1 if efile_sub
  end

  $is_debug = debug_flag
  $is_debug_verbose = verbose_flag

  queue = Queue.new

  thread1 = Thread.new {
    loop do
      break if is_exitting
      ie = evdev.read_input_event
      queue.push(ie)
    end
  }

  if evdev_sub
    thread2 = Thread.new {
      loop do
        break if is_exitting
        ie = evdev_sub.read_input_event
        queue.push(ie)
      end
    }
  end

  loop do
    # ie = evdev.read_input_event
    ie = queue.pop
    # t = ie.hr_type ? "#{ie.hr_type.to_s}(#{ie.type})" : ie.type
    # c = ie.hr_code ? "#{ie.hr_code.to_s}(#{ie.code})" : ie.code
    # v = ie.hr_value ? "#{ie.hr_value.to_s}(#{ie.value})" : ie.value
    # puts "type:#{t}	code:#{c}	value:#{v}"

    uinput_write_input ie

    # uinput_write_input_event.call ie
    # puts "type:#{t}	code:#{c}	value:#{v}"

  end

end

main
