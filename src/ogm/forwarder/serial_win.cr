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

  GENERIC_READ  = 0x80000000_u32
  GENERIC_WRITE = 0x40000000_u32
  OPEN_EXISTING = 3_u32
  FILE_ATTRIBUTE_NORMAL = 0x80_u32

  PURGE_TXABORT = 0x0001_u32
  PURGE_RXABORT = 0x0002_u32
  PURGE_TXCLEAR = 0x0004_u32
  PURGE_RXCLEAR = 0x0008_u32

  SETXOFF  = 1_u32
  SETXON   = 2_u32
  SETRTS   = 3_u32
  CLRRTS   = 4_u32
  SETDTR   = 5_u32
  CLRDTR   = 6_u32
  SETBREAK = 8_u32  
  CLRBREAK = 9_u32
  
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
  fun GetLastError : UInt32
  fun PurgeComm(hFile : HANDLE, dwFlags : UInt32) : LibC::BOOL
  fun EscapeCommFunction(hFile : HANDLE, dwFunc : UInt32) : LibC::BOOL
  fun FlushFileBuffers(hFile : HANDLE) : LibC::BOOL
end

{% end %}

module OGM::Forwarder::SerialWin
  # tiny helpers
  private def self.to_wstr(s : String) : LibC::LPWSTR
    (s + "\0").encode("UTF-16LE").to_unsafe.as(LibC::LPWSTR)
  end

  private def self.invalid_handle?(h : LibC::HANDLE) : Bool
    # INVALID_HANDLE_VALUE == (void*)(-1)
    h.null? || h.address == UInt64::MAX
  end

  private def self.last_error : UInt32
    LibC.GetLastError
  end

  def self.open_port(dev : String, baud : Int32) : IO
    path = dev.starts_with?("\\\\.\\") ? dev : "\\\\.\\#{dev}"

    h = LibC.CreateFileW(
      to_wstr(path),
      Win32::GENERIC_READ | Win32::GENERIC_WRITE,
      0_u32,                                           # no sharing
      Pointer(LibC::SECURITY_ATTRIBUTES).null,
      Win32::OPEN_EXISTING,
      Win32::FILE_ATTRIBUTE_NORMAL,
      LibC::HANDLE.null
    )

    if invalid_handle?(h)
      code = last_error
      raise "CreateFileW failed for #{path} (GetLastError=#{code})"
    end

    configure_handle(h, baud)

    # handle = h.address.as(IO::FileDescriptor::Handle)
    # IO::FileDescriptor.new(handle: handle, close_on_finalize: true)

    SerialWinIO.new(h)   
  end

  def self.configure_handle(h : LibC::HANDLE, baud : Int32)
    # --- DCB ---
    dcb = Win32::DCB.new
    dcb.dcbLength = sizeof(Win32::DCB).to_u32
    raise "GetCommState failed" unless Win32.GetCommState(h, pointerof(dcb)) != 0

    dcb.baudRate = baud.to_u32
    dcb.byteSize = 8_u8
    dcb.parity   = 0_u8  # NOPARITY
    dcb.stopBits = 0_u8  # ONESTOPBIT

    # DCB flags layout (common bits):
    # bit0  fBinary
    # bit2  fOutxCtsFlow
    # bit3  fOutxDsrFlow
    # bit4-5  fDtrControl (00=DISABLE, 01=ENABLE, 02=HANDSHAKE)
    # bit8  fOutX   (XON/XOFF out)
    # bit9  fInX    (XON/XOFF in)
    # bit12-13 fRtsControl (00=DISABLE, 01=ENABLE, 02=HANDSHAKE, 03=TOGGLE)
    #
    # Build flags explicitly: binary on, NO flow control, RTS/DTR enabled.
    flags = 0_u32
    flags |= 1_u32 << 0                      # fBinary = TRUE
    # fOutxCtsFlow = 0 (off)
    # fOutxDsrFlow = 0 (off)
    # fOutX/fInX   = 0 (off)
    flags |= (1_u32 << 4)                    # fDtrControl = ENABLE (01 in bits 4-5)
    flags |= (1_u32 << 12)                   # fRtsControl = ENABLE (01 in bits 12-13)

    dcb.flags = flags

    raise "SetCommState failed" unless Win32.SetCommState(h, pointerof(dcb)) != 0

    # Optionally size driver queues (not required but nice):
    # Win32.SetupComm(h, 4096_u32, 4096_u32)

    # Clean any stale buffered bytes and assert lines once:
    Win32.PurgeComm(h, Win32::PURGE_RXCLEAR | Win32::PURGE_TXCLEAR)
    Win32.EscapeCommFunction(h, Win32::SETDTR)
    Win32.EscapeCommFunction(h, Win32::SETRTS)

    # --- COMMTIMEOUTS ---
    timeouts = Win32::COMMTIMEOUTS.new
    raise "GetCommTimeouts failed" unless Win32.GetCommTimeouts(h, pointerof(timeouts)) != 0

    # --- COMMTIMEOUTS (non-blocking-ish) ---
    timeouts.readIntervalTimeout         = 0_u32
    timeouts.readTotalTimeoutMultiplier  = 0_u32
    timeouts.readTotalTimeoutConstant    = 1_u32  # ~1ms poll
    timeouts.writeTotalTimeoutMultiplier = 0_u32
    timeouts.writeTotalTimeoutConstant   = 1_u32
    Win32.SetCommTimeouts(h, pointerof(timeouts))

    raise "SetCommTimeouts failed" unless Win32.SetCommTimeouts(h, pointerof(timeouts)) != 0
  end

end