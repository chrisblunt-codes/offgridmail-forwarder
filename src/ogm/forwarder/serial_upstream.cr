# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

require "./upstream"

{% if flag?(:unix) %}
  require "./serial_posix"
  require "./serial_posix_lines"
  require "./serial_posix_io"
{% end %}

{% if flag?(:win32) %}
  require "./serial_win"
{% end %}


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
        port = File.open(@dev, "r+")
        port.sync = true
        force_baud!(@dev, @baud)                    # via stty helper
        SerialPosix.configure_port(port.fd, @baud)  # raw 8N1, no HW/SW flow, VMIN=1/VTIME=0
        SerialPosixLines.assert_rts_dtr(port.fd)    # raise RTS/DTR once
        serial = PosixSerialIO.new(port, port.fd)   # << return this
        serial
      {% elsif flag?(:win32) %}
        Log.info { "Opening serial #{normalize_win_dev(@dev)} (baud #{@baud}) [Windows]" }

        port = SerialWin.open_port(normalize_win_dev(@dev), @baud)
        port
      {% else %}
        raise "SerialUpstream not implemented on this platform yet"
      {% end %}
    end

    private def normalize_win_dev(dev : String) : String
      # Accept "COM3" or "\\.\COM3"
      dev.starts_with?("\\\\.\\") ? dev : "\\\\.\\#{dev}"
    end

    private def force_baud!(dev : String, baud : Int32)
      args = ["-F", dev, baud.to_s, "-ixon", "-ixoff", "-crtscts", "-opost", "cs8", "-cstopb", "-parenb", "-echo", "clocal"]
      status = Process.run("stty", args: args)
      raise "stty failed (exit #{status.exit_code})" unless status.success?
    end
  end
end
