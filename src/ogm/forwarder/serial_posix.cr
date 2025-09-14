# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0


{% if flag?(:linux) || flag?(:darwin) %}
lib LibC
  fun tcflush(fd : Int32, queue_selector : Int32) : Int32
  fun tcdrain(fd : Int32) : Int32
end
{% end %}

module OGM::Forwarder
  module SerialPosix
    CSIZE_MASK = (LibC::CS5 | LibC::CS6 | LibC::CS7 | LibC::CS8).to_u32

    {% if flag?(:linux) %}
      # Some Crystal LibC builds don't expose CRTSCTS/VMIN/VTIME; use indices/masks.
      CRTSCTS_MASK = 0x80000000_u32
      VTIME_IDX  = 5
      VMIN_IDX   = 6
    {% elsif flag?(:darwin) %}
      VMIN_IDX  = 16
      VTIME_IDX = 17
    {% end %}

    # tcflush selectors (keep them here, not inside LibC)
    TCIFLUSH  = 0
    TCOFLUSH  = 1
    TCIOFLUSH = 2

    def self.configure_port(fd : Int32, _baud : Int32)
      tio = LibC::Termios.new
      raise "tcgetattr failed" unless LibC.tcgetattr(fd, pointerof(tio)) == 0

      # Raw baseline
      LibC.cfmakeraw(pointerof(tio))

      # 8N1, receiver enabled, ignore modem control in termios
      tio.c_cflag &= ~CSIZE_MASK
      tio.c_cflag |=  LibC::CS8 | LibC::CREAD | LibC::CLOCAL
      tio.c_cflag &= ~LibC::PARENB
      tio.c_cflag &= ~LibC::CSTOPB

      # Hardware flow OFF (Linux) / RTS/CTS OFF (Darwin)
      {% if flag?(:linux) %}
        tio.c_cflag &= ~CRTSCTS_MASK
      {% elsif flag?(:darwin) %}
        tio.c_cflag &= ~(LibC::CRTS_IFLOW | LibC::CCTS_OFLOW)
      {% end %}

      # Software flow OFF
      tio.c_iflag &= ~(LibC::IXON | LibC::IXOFF | LibC::IXANY)

      # Read returns as soon as 1 byte arrives
      tio.c_cc[VMIN_IDX]  = 1_u8
      tio.c_cc[VTIME_IDX] = 0_u8

      # Apply immediately
      raise "tcsetattr failed" unless LibC.tcsetattr(fd, LibC::TCSANOW, pointerof(tio)) == 0

      # Flush stale data
      {% if flag?(:linux) || flag?(:darwin) %}
        # LibC.tcflush(fd, LibC::TCIOFLUSH)
      {% end %}
    end
  end
end
