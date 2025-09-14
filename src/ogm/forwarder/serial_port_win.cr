# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

{% if flag?(:win32) %}
require "log"

lib Win
  alias HANDLE = LibC::HANDLE
  alias DWORD  = LibC::DWORD
  alias BOOL   = LibC::BOOL
  alias UINT   = LibC::UINT
  alias WORD   = LibC::WORD
  alias BYTE   = UInt8
  alias LPSTR  = LibC::LPSTR
  alias INTPTR = LibC::intptr_t
  alias CINT   = LibC::CInt

  @[Extern]
  struct DCB
    DCBlength : DWORD
    BaudRate  : DWORD
    flags     : DWORD       # we won’t poke this directly
    wReserved : WORD
    XonLim    : WORD
    XoffLim   : WORD
    ByteSize  : BYTE
    Parity    : BYTE
    StopBits  : BYTE
    XonChar   : Int8
    XoffChar  : Int8
    ErrorChar : Int8
    EofChar   : Int8
    EvtChar   : Int8
    wReserved1 : WORD
  end

  @[Extern]
  struct COMMTIMEOUTS
    ReadIntervalTimeout         : DWORD
    ReadTotalTimeoutMultiplier  : DWORD
    ReadTotalTimeoutConstant    : DWORD
    WriteTotalTimeoutMultiplier : DWORD
    WriteTotalTimeoutConstant   : DWORD
  end

  fun BuildCommDCBA(defn : LPSTR, dcb : DCB*) : BOOL
  fun GetCommState(h : HANDLE, dcb : DCB*) : BOOL
  fun SetCommState(h : HANDLE, dcb : DCB*) : BOOL
  fun SetCommTimeouts(h : HANDLE, tmo : COMTTIMEOUTS*) : BOOL
  fun SetupComm(h : HANDLE, in_q : DWORD, out_q : DWORD) : BOOL
  fun PurgeComm(h : HANDLE, flags : DWORD) : BOOL

  # CRT helper to convert fd → HANDLE
  fun _get_osfhandle(fd : CINT) : INTPTR
end

module OGM::Forwarder
  module SerialWin
    # Configure a Windows serial port for raw 8N1 at the given baud.
    # Uses the underlying HANDLE from a Crystal File.
    def self.configure_file(file : File, baud : Int32)
      handle_int = Win._get_osfhandle(file.fd)
      raise "invalid handle from fd" if handle_int <= 0
      h = Pointer(Win::HANDLE).new(handle_int).value

      # Build DCB via a definition string (avoids bitfields).
      # parity=n|o|e, data=8, stop=1|2, rts/dtr off (no HW flow), xon/off off.
      defn = "baud=#{baud} parity=n data=8 stop=1 xon=off odsr=off octs=off dtr=off rts=off"
      dcb = Win::DCB.new
      dcb.DCBlength = sizeof(Win::DCB).to_u32
      ok = Win.BuildCommDCBA(defn.to_unsafe, pointerof(dcb))
      raise "BuildCommDCBA failed" unless ok == 1

      raise "SetCommState failed" unless Win.SetCommState(h, pointerof(dcb)) == 1

      # Queue sizes (optional sane defaults)
      Win.SetupComm(h, 4096, 4096)

      # Blocking reads until at least 1 byte; no write timeouts.
      tmo = Win::COMMTIMEOUTS.new
      tmo.ReadIntervalTimeout         = 0
      tmo.ReadTotalTimeoutMultiplier  = 0
      tmo.ReadTotalTimeoutConstant    = 0
      tmo.WriteTotalTimeoutMultiplier = 0
      tmo.WriteTotalTimeoutConstant   = 0
      raise "SetCommTimeouts failed" unless Win.SetCommTimeouts(h, pointerof(tmo)) == 1

      # Purge any stale I/O
      # 0x0008=PURGE_RXCLEAR, 0x0004=PURGE_TXCLEAR
      Win.PurgeComm(h, 0x0008_u32 | 0x0004_u32)
    end
  end
end
{% end %}
