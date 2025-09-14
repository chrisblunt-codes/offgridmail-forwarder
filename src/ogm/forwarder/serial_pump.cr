# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0
require "socket"

require "log"
require "./upstream"


{% if flag?(:unix) %}  require "./serial_port_unix" {% end %}
{% if flag?(:win32) %} require "./serial_port_win"  {% end %}

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
      @remote = @upstream.connect
      serial  = @serial.not_nil!
      remote  = @remote.not_nil!
      
      set_timeouts(remote, @rw_timeout)

      c1 = Channel(Nil).new
      c2 = Channel(Nil).new

      spawn do
        begin
          IO.copy(serial, remote)
        rescue ex
          Log.debug { "pump serial→tcp ended: #{ex.message}" }
        ensure
          remote.close rescue nil
          c1.send(nil)
        end
      end

      spawn do
        begin
          IO.copy(remote, serial)
        rescue ex
          Log.debug { "pump tcp→serial ended: #{ex.message}" }
        ensure
          serial.close rescue nil
          c2.send(nil)
        end
      end

      c1.receive; c2.receive
    ensure
      stop
    end

    def stop
      return if @stopping.swap(true)

      @serial.try { |io| io.close rescue nil }
      @remote.try { |io| io.close rescue nil }
    end

    private def open_serial(dev : String, baud : Int32) : IO
      {% if flag?(:unix) %}
        Log.info { "Opening serial #{dev} (baud #{baud})" }
        io = File.open(dev, "r+")
        Serial.configure_fd(io.fd, baud)
        io
      {% elsif flag?(:win32) %}
        path = normalize_win_dev(dev)
        Log.info { "Opening serial #{path} (baud #{baud}) [Windows]" }
        io = File.open(path, "r+")
        SerialWin.configure_file(io, @baud) 
        io
      {% else %}
        raise "Serial pump not implemented on this platform yet"
      {% end %}
    end

    private def set_timeouts(io : IO, t : Time::Span)
      # Apply only if it's a TCPSocket
      if io.is_a?(TCPSocket)
        io.read_timeout  = t
        io.write_timeout = t
      end
    end

    private def normalize_win_dev(dev : String) : String
      d = dev.upcase
      d.starts_with?("\\\\.\\") ? d : "\\\\.\\#{d}"
    end
  end
end
