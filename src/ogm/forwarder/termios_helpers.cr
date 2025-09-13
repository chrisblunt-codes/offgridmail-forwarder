# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

module OGM::Forwarder
  module Serial
    CSIZE_MASK = (LibC::CS5 | LibC::CS6 | LibC::CS7 | LibC::CS8).to_u32

    def self.configure_fd(fd : Int32, baud : Int32)
      tio = LibC::Termios.new
      raise "tcgetattr failed" if LibC.tcgetattr(fd, pointerof(tio)) != 0

      # Raw mode (portable) – turns off canonical mode, echo, translations, etc.
      LibC.cfmakeraw(pointerof(tio))

      # Ensure 8N1, receiver enabled, ignore modem control
      tio.c_cflag &= ~CSIZE_MASK
      tio.c_cflag &= ~LibC::PARENB
      tio.c_cflag &= ~LibC::CSTOPB
      tio.c_cflag |=  LibC::CS8 | LibC::CREAD | LibC::CLOCAL

      # Apply immediately. (No tcflush — some LibC bindings don’t have it.)
      raise "tcsetattr failed" if LibC.tcsetattr(fd, LibC::TCSANOW, pointerof(tio)) != 0

      # NOTE: We’re not setting baud here to avoid missing LibC::B* constants.
      # Configure speed externally with `stty` if needed (documented in README).
    end
  end
end
