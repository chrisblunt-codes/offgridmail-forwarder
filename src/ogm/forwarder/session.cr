# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

require "./upstream"


module OGM::Forwarder
  class Session
    @target : IO? = nil
    @closed = Atomic(Bool).new(false)

    def initialize(
      @id           : Int64,
      @client       : TCPSocket,
      @upstream     : Upstream,
      @rw_timeout   : Time::Span
    )
    end

    def run
      started = Time.monotonic
      target  = @upstream.connect
      @target = target

      c_bytes, t_bytes = bidi_proxy(@client, target, @rw_timeout)

      log_session(started, c_bytes, t_bytes)
    rescue ex
      Log.warn { "##{@id}] Session error: #{ex.message}" }
    ensure
      force_close
    end

    # allow Listener to kill lingering sessions
    def force_close
      return if @closed.swap(true)
      @client.close rescue nil
      @target.try &.close rescue nil
    end

    private def set_timeouts(io : TCPSocket, t : Time::Span)
      io.read_timeout = t
      io.write_timeout = t
    end

    private def set_timeouts(io : IO, t : Time::Span)
      # Non-socket IO (e.g., serial File) — no timeouts to set.
    end

    private def bidi_proxy(client : IO, target : IO, rw_timeout : Time::Span)
      set_timeouts(client, rw_timeout)
      set_timeouts(target, rw_timeout)

      c2t_done = Channel(Int64).new
      t2c_done = Channel(Int64).new

      spawn do
        bytes = 0_i64

        begin
          bytes = IO.copy(client, target)
        rescue ex
          Log.debug { "[##{@id}] c→t ended: #{ex.message}" }
        ensure
          target.close rescue nil
          c2t_done.send(bytes)
        end
      end

      spawn do
        bytes = 0_i64

        begin
          bytes = IO.copy(target, client)
        rescue ex
          Log.debug { "[##{@id}] t→c ended: #{ex.message}" }
        ensure
          client.close rescue nil
          t2c_done.send(bytes)
        end
      end

      { c2t_done.receive, t2c_done.receive }
    end

    private def log_session(started, c_bytes, t_bytes)
      dur = (Time.monotonic - started).total_seconds
      Log.debug { "[##{@id}] ended. duration=#{dur.round(3)}s  c→t=#{c_bytes}B  t→c=#{t_bytes}B" }
    end
  end
end