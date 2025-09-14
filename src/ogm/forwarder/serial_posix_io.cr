# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

{% if flag?(:linux) || flag?(:darwin) %}
class PosixSerialIO < IO
  def initialize(@file : File, @fd : Int32); end

  def read(slice : Bytes) : Int32
    @file.read(slice)
  end

  # IO#write returns Nil (must write whole slice or raise)
  def write(slice : Bytes) : Nil
    @file.write(slice)
    nil
  end

  def flush : Nil
    @file.flush
    LibC.tcdrain(@fd)  # ensure bytes actually leave the UART
    nil
  end

  def close : Nil
    @file.close
  end

  def read_timeout=(t : Time::Span);  @file.read_timeout  = t; end
  def write_timeout=(t : Time::Span); @file.write_timeout = t; end
end
{% end %}
