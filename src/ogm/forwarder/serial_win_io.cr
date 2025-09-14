# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

{% if flag?(:win32) %}

require "./serial_win"  

class SerialWinIO < IO
  def initialize(@h : Win32::HANDLE); end

  def read(slice : Bytes) : Int32
    got = uninitialized LibC::DWORD
    ok  = LibC.ReadFile(@h, slice.to_unsafe, slice.size.to_u32, pointerof(got), Pointer(LibC::OVERLAPPED).null)
    raise "ReadFile failed (#{LibC.GetLastError})" if ok == 0
    got.to_i
  end

  # IO#write returns Nil in Crystal (must write entire slice or raise)
  def write(slice : Bytes) : Nil
    put = uninitialized LibC::DWORD
    ok  = LibC.WriteFile(@h, slice.to_unsafe, slice.size.to_u32, pointerof(put), Pointer(LibC::OVERLAPPED).null)
    raise "WriteFile failed (#{LibC.GetLastError})" if ok == 0
    raise "Short write to serial (#{put}/#{slice.size})" if put != slice.size
  end

  def flush : Nil
    Win32.FlushFileBuffers(@h)   # actually pushes driver buffers now
  end

  def close : Nil
    LibC.CloseHandle(@h)
  end
end

{% end %}
