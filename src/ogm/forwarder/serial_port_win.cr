# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

{% if flag?(:win32) %}

lib Win32
  alias DWORD  = UInt32
  alias WORD   = UInt16
  alias BYTE   = UInt8
  alias BOOL   = Int32
  alias HANDLE = LibC::HANDLE
  alias LPSTR  = LibC::LPSTR

  # DCB (bitfields collapsed into a single UInt32 'flags')
  struct DCB
    dcbLength : DWORD
    baudRate  : DWORD
    flags     : DWORD      # fBinary..fAbortOnError (+ padding) packed into one 32-bit field
    wReserved : WORD
    xonLim    : WORD
    xoffLim   : WORD
    byteSize  : BYTE
    parity    : BYTE
    stopBits  : BYTE
    xonChar   : Int8       # CHAR
    xoffChar  : Int8
    errorChar : Int8
    eofChar   : Int8
    evtChar   : Int8
    wReserved1 : WORD
  end

  struct COMMTIMEOUTS
    readIntervalTimeout         : DWORD
    readTotalTimeoutMultiplier  : DWORD
    readTotalTimeoutConstant    : DWORD
    writeTotalTimeoutMultiplier : DWORD
    writeTotalTimeoutConstant   : DWORD
  end

  fun BuildCommDCBA(lpszDef : LPSTR, lpDCB : DCB*) : BOOL
  fun GetCommState(hFile : HANDLE, lpDCB : DCB*) : BOOL
  fun SetCommState(hFile : HANDLE, lpDCB : DCB*) : BOOL
  fun GetCommTimeouts(hFile : HANDLE, lpCommTimeouts : COMMTIMEOUTS*) : BOOL
  fun SetCommTimeouts(hFile : HANDLE, lpCommTimeouts : COMMTIMEOUTS*) : BOOL
end

{% end %}


module OGM::Forwarder
  module SerialWin
    # Configure a Windows serial port for raw 8N1 at the given baud.
    def self.configure_file(file : File, baud : Int32)
      h = handle_for(file)
      raise "invalid handle from fd" if h.null?

      # Use h directly; don't re-wrap it.
      dcb = Win32::DCB.new
      dcb.dcbLength = sizeof(Win32::DCB).to_u32

      ok = Win32.GetCommState(h, pointerof(dcb)) != 0
      raise "GetCommState failed" unless ok

      # e.g., set baud via BuildCommDCBA (ANSI C-string ok for immediate call)
      str = "baud=#{baud},n,8,1"
      ok = Win32.BuildCommDCBA(str.to_unsafe, pointerof(dcb)) != 0
      raise "BuildCommDCBA failed" unless ok

      ok = Win32.SetCommState(h, pointerof(dcb)) != 0
      raise "SetCommState failed" unless ok

      timeouts = Win32::COMMTIMEOUTS.new
      ok = Win32.GetCommTimeouts(h, pointerof(timeouts)) != 0
      raise "GetCommTimeouts failed" unless ok

      # reasonable defaults
      timeouts.readIntervalTimeout         = 50
      timeouts.readTotalTimeoutMultiplier  = 10
      timeouts.readTotalTimeoutConstant    = 50
      timeouts.writeTotalTimeoutMultiplier = 10
      timeouts.writeTotalTimeoutConstant   = 50

      ok = Win32.SetCommTimeouts(h, pointerof(timeouts)) != 0
      raise "SetCommTimeouts failed" unless ok
    end

    def self.handle_for(file : File) : Win32::HANDLE
      ip = LibC._get_osfhandle(file.fd)   # intptr_t
      # _get_osfhandle returns -1 on error
      return Pointer(Void).null if ip < 0
      Pointer(Void).new(ip.to_u64)
    end
  end
end

