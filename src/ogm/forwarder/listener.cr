# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

module OGM::Forwarder
  class Listener
    @server : TCPServer? = nil
    @stopping   = false
    @lock       = Mutex.new
    @sessions   = Set(Session).new

    def initialize(@cfg : Config, @selector : UpstreamSelector)
    end

    def run
      @server = TCPServer.new(@cfg.listen_host, @cfg.listen_port)
      puts "Listening on #{@cfg.listen_host}:#{@cfg.listen_port} (primary: #{@cfg.primary}, backup: #{@cfg.backup})"

      loop do
        break if @stopping
        begin
          client = @server.not_nil!.accept
        rescue ex : IO::Error
          break if @stopping
          raise ex
        end

        session = Session.new(client, @selector, @cfg.rw_timeout)
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
      
      puts "Draining #{n} active session(s) for up to #{grace.total_seconds.to_i}s…" if n > 0

      while (n = active_sessions) > 0 && Time.monotonic < deadline
        remaining = deadline - Time.monotonic
        puts "#{n} active session(s) remaining (#{remaining.total_seconds.to_i}s remaining)"
        sleep interval
      end

      if (n = active_sessions) > 0
        puts "Grace ended; forcing close on #{n} session(s)..."
        force_close_all
        t_end = Time.monotonic + hard_kill_wait
        while active_sessions > 0 && Time.monotonic < t_end
          sleep 0.05.seconds
        end
      else
        puts "All sessions drained."
      end
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