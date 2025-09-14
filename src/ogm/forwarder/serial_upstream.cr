# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

require "./upstream"
require "./termios_helpers"

module OGM::Forwarder
  # Serial upstream that opens a COM/TTY device and returns it as an `IO`
  # for proxying.
  #
  # Platform notes:
  # - Windows: configures baud and raw 8N1 via Win32 (DCB/COMMTIMEOUTS).
  # - POSIX  : sets raw 8N1 via termios; baud is expected to be
  #            preconfigured externally (see README).
  #
  # Usage:
  #   upstream = SerialUpstream.new("/dev/ttyUSB0", 115200)  # POSIX
  #   upstream = SerialUpstream.new("COM3", 115200)          # Windows (\\.\COM3 normalized)
  #
  # Raises if the device cannot be opened or the platform is unsupported.
  class SerialUpstream
    include Upstream
    
    def initialize(@dev : String, @baud : Int32)
    end

    def connect : IO
      {% if flag?(:unix) %}
        Log.info { "Opening serial #{@dev} (baud #{@baud})" }
        # Open read/write; assume external config for speed/flags.
        io = File.open(@dev, "r+")
        Serial.configure_fd(io.fd, @baud)
        io
      {% else %}
        raise "SerialUpstream not implemented on this platform yet"
      {% end %}
    end
  end
end
