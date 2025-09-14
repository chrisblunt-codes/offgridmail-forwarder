# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

require "./upstream"
require "./termios_helpers"

module OGM::Forwarder
  # Minimal serial upstream: opens a device file as IO.
  # NOTE: This stub relies on the device being preconfigured (e.g., via `stty`).
  # Proper termios config can be added later.
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
