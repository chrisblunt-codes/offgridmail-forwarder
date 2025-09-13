# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

module OGM::Forwarder
  class Listener
    @server : TCPServer? = nil
    @stopping     = false
    @lock         = Mutex.new
    @sessions     = Set(Session).new
    @seq          = 0_i64

    def initialize(@cfg : Config, @upstream : Upstream)
    end

    def run
      @server = TCPServer.new(@cfg.listen_host, @cfg.listen_port)
      log_settings

      loop do
        break if @stopping
        begin
          client = @server.not_nil!.accept
        rescue ex : IO::Error
          break if @stopping
          raise ex
        end

        id = next_id
        session = Session.new(id, client, @upstream, @cfg.rw_timeout)
        track_add(session)

        spawn do
          begin
            session.run
          ensure
            track_remove(session)
          end
        end
      end
    ensure
      @server.try &.close
    end

    def stop
      @stopping = true
      @server.try { |s| s.close rescue nil }
    end

    def active_sessions : Int32
      @lock.synchronize { @sessions.size }
    end

    def wait_for_drain(grace : Time::Span = 10.seconds, interval : Time::Span = 0.5.seconds, hard_kill_wait : Time::Span = 1.seconds)
      deadline = Time.monotonic + grace
      n = active_sessions
      
      Log.info { "Draining #{n} active session(s) for up to #{grace.total_seconds.to_i}s…" } if n > 0

      while (n = active_sessions) > 0 && Time.monotonic < deadline
        remaining = deadline - Time.monotonic
        Log.debug { "#{n} active session(s) remaining (#{remaining.total_seconds.to_i}s remaining)" }
        sleep interval
      end

      if (n = active_sessions) > 0
        Log.info { "Grace ended; forcing close on #{n} session(s)..." }
        force_close_all
        t_end = Time.monotonic + hard_kill_wait
        while active_sessions > 0 && Time.monotonic < t_end
          sleep 0.05.seconds
        end
      else
        Log.info { "All sessions drained." }
      end
    end

    private def log_settings
      listen_on = "Listening on [#{@cfg.listen_host}:#{@cfg.listen_port}]"

      forward_to  = case @cfg.upstream_mode
                    when UpstreamMode::Tcp
                      "Forwarding to [#{@cfg.primary.host}:#{@cfg.primary.port}] or [#{@cfg.backup.host}:#{@cfg.backup.port}]"
                    when UpstreamMode::Serial
                      "Forwarding to [#{@cfg.serial_dev}]"
                    end    
      Log.info { "#{listen_on} and #{forward_to}" }
    end

    private def next_id : Int64
      @lock.synchronize { @seq += 1; @seq }
    end

    private def track_add(s : Session)
      @lock.synchronize { @sessions.add(s) }
    end

    private def track_remove(s : Session)
      @lock.synchronize { @sessions.delete(s) }
    end

    private def force_close_all
      @lock.synchronize { @sessions.each &.force_close }
    end
  end
end