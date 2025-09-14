# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

module SerialPosixLines
  lib LibC
    TIOCMGET  = 0x5415_u64
    TIOCMSET  = 0x5418_u64
    TIOCM_DTR = 0x002
    TIOCM_RTS = 0x004
    
    fun ioctl(fd : Int32, req : UInt64, arg : Void*) : Int32
  end

  def self.assert_rts_dtr(fd : Int32)
    flags = uninitialized Int32
    LibC.ioctl(fd, LibC::TIOCMGET, pointerof(flags))
    flags |= LibC::TIOCM_DTR | LibC::TIOCM_RTS
    LibC.ioctl(fd, LibC::TIOCMSET, pointerof(flags))
  end
end