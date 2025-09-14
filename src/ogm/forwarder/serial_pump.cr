# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"

require "log"

require "./auto_flush_io"
require "./upstream"


{% if flag?(:unix) %}  require "./serial_posix" {% end %}
{% if flag?(:win32) %} require "./serial_win"   {% end %}

module OGM::Forwarder
  class SerialTcpPump
    @serial    : IO? = nil
    @remote    : IO? = nil
    @stopping  : Atomic(Bool)

    def initialize(@dev : String, @baud : Int32, @upstream : Upstream, @rw_timeout : Time::Span)
      @stopping = Atomic(Bool).new(false)
    end

    def run
      @serial = open_serial(@dev, @baud)
      puts "[pump] opened serial #{@dev} (#{@baud} baud)"
      @remote = @upstream.connect
      puts "[pump] connected to upstream #{peer_str(@remote.not_nil!)}"

      serial = @serial.not_nil!
      remote = @remote.not_nil!

      # TCP socket tweaks: no read timeout so reads block
      if remote.is_a?(TCPSocket)
        remote.tcp_nodelay = true
        remote.write_timeout = @rw_timeout
      end

      puts "[pump] scheduling SER→TCP fiber"
      c1 = Channel(Nil).new
      spawn do
        puts "[pump] ENTER SER→TCP fiber"
        begin
          buf = Bytes.new(4096)
          loop do
            n = serial.read(buf)           # may return 0 when no data within ~1ms
            if n == 0
              # not EOF on a COM port — just “no data yet”
              Fiber.yield
              next
            end
            puts "SER→TCP #{n}B"
            remote.write buf[0, n]
            remote.flush
          end
        rescue ex
          puts "SER→TCP ended: #{ex.message}"
        ensure
          remote.close rescue nil
          c1.send(nil)
        end
      end
      puts "[pump] scheduled SER→TCP fiber"

      puts "[pump] scheduling TCP→SER fiber"
      c2 = Channel(Nil).new
      spawn do
        puts "[pump] ENTER TCP→SER fiber"
        begin
          buf = Bytes.new(4096)
          loop do
            n = remote.read(buf)               # blocking
            break if n == 0
            puts "TCP→SER #{n}B"
            serial.write buf[0, n]
            serial.flush                       # IMPORTANT: your SerialWinIO.flush -> FlushFileBuffers
          end
        rescue ex
          puts "TCP→SER ended: #{ex.message}"
        ensure
          serial.close rescue nil
          c2.send(nil)
        end
      end
      puts "[pump] scheduled TCP→SER fiber"

      # Give the scheduler a chance to run both fibers immediately
      Fiber.yield

      # Wait for both sides to finish
      c1.receive
      c2.receive
    ensure
      stop
    end

    private def peer_str(io : IO)
      if io.is_a?(TCPSocket)
        (io.remote_address || io.local_address).to_s
      else
        io.class.name
      end
    end

    def stop
      return if @stopping.swap(true)

      @serial.try { |io| io.close rescue nil }
      @remote.try { |io| io.close rescue nil }
    end

    private def open_serial(dev : String, baud : Int32) : IO
      {% if flag?(:win32) %}
        SerialWin.open_port(dev, baud)   # returns an IO
      {% else %}
        port = File.open(dev, "r+")
        SerialPosix.configure_port(port.fd, baud)
        port
      {% end %}
    end

    private def set_timeouts(io : IO, t : Time::Span)
      # Apply only if it's a TCPSocket
      if io.is_a?(TCPSocket)
        io.tcp_nodelay   = true
        # io.read_timeout  = t   # ← leave reads blocking
        io.write_timeout = t
      end
    end

    private def normalize_win_dev(dev : String) : String
      d = dev.upcase
      d.starts_with?("\\\\.\\") ? d : "\\\\.\\#{d}"
    end

    private def peek(buf : Bytes, n : Int32) : String
      m = Math.min(n, 48)
      s = String.build do |sb|
        # try to show printable preview
        sb << "'"
        m.times do |i|
          ch = buf[i]
          sb << (ch >= 32 && ch < 127 ? ch.chr : '.')
        end
        sb << "' "
        sb << buf[0, Math.min(n, 16)].to_a.map { |b| b.to_s(16).rjust(2, '0') }.join(" ")
      end
      s
    end

    # UTF-16LE null-terminated pointer for CreateFileW
    def to_wstr(s : String) : LibC::LPWSTR
      (s + "\0").encode("UTF-16LE").to_unsafe.as(LibC::LPWSTR)
    end
  end
end
