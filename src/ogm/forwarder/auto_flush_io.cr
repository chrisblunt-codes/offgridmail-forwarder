# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

# Auto-flushes after every write, delegating all ops to the wrapped IO.
class AutoFlushIO < IO
  def initialize(@io : IO)
  end

  # delegate reads
  def read(slice : Bytes) : Int32
    @io.read(slice)
  end

  def write(slice : Bytes) : Nil
    @io.write(slice)  # writes all bytes or raises
    @io.flush
    nil
  end

  # pass-throughs
  def flush : Nil
    @io.flush
  end

  def close : Nil
    @io.close
  end

  def read_timeout=(t : Time::Span);  @io.read_timeout  = t; end
  def write_timeout=(t : Time::Span); @io.write_timeout = t; end
end
