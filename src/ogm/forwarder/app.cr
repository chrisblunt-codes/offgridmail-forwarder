# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"

require "./config"

module OGM::Forwarder
  module App
    # Starts the forwarder service.
    #
    # Opens a TCP server on the configured listen host/port,
    # accepts incoming client connections, and forwards them
    # to the primary or backup upstream.
    #
    # @param cfg [Config] runtime configuration with listen address,
    # upstream hosts, and timeouts
    def self.run(cfg : Config)
      server = TCPServer.new(cfg.listen_host, cfg.listen_port)
      puts "Listening on #{cfg.listen_host}:#{cfg.listen_port} " \
           "(primary: #{cfg.primary}, backup: #{cfg.backup})"

      loop do
        client = server.accept
        spawn do
          begin
            target = connect_with_failover(cfg)
            bidi_proxy(client, target, cfg.rw_timeout)
          rescue ex
            puts "Session error: #{ex.message}"
            client.close rescue nil
          end
        end
      end
    end

    # Attempts to connect to the primary upstream first.
    # Falls back to the backup if the primary is unavailable.
    #
    # @param cfg [Config] runtime configuration with upstream hosts and timeouts
    # @return [TCPSocket] an open socket to the chosen upstream
    private def self.connect_with_failover(cfg : Config) : TCPSocket
      begin
        sock = TCPSocket.new(cfg.primary.host, cfg.primary.port,
                             connect_timeout: cfg.connect_timeout)
        puts "→ Using PRIMARY #{cfg.primary}"
        return sock
      rescue ex
        puts "Primary failed: #{ex.message}"
      end

      sock = TCPSocket.new(cfg.backup.host, cfg.backup.port,
                           connect_timeout: cfg.connect_timeout)
      puts "→ Using BACKUP  #{cfg.backup}"
      sock
    end

    # Proxies data bidirectionally between a client and target socket.
    #
    # Spawns two fibers: one for client→target, and one for target→client.
    # Both sockets are closed when either direction ends or an error occurs.
    #
    # @param client [TCPSocket] the accepted downstream connection
    # @param target [TCPSocket] the upstream server connection
    # @param rw_timeout [Time::Span] read/write timeout applied to both sockets
    private def self.bidi_proxy(client : TCPSocket, target : TCPSocket, rw_timeout : Time::Span)
      client.read_timeout  = rw_timeout
      client.write_timeout = rw_timeout
      target.read_timeout  = rw_timeout
      target.write_timeout = rw_timeout

      c2t_done = Channel(Nil).new
      t2c_done = Channel(Nil).new

      spawn do
        begin
          IO.copy(client, target)
        rescue ex
          puts "c→t ended: #{ex.message}"
        ensure
          target.close rescue nil
          c2t_done.send(nil)
        end
      end

      spawn do
        begin
          IO.copy(target, client)
        rescue ex
          puts "t→c ended: #{ex.message}"
        ensure
          client.close rescue nil
          t2c_done.send(nil)
        end
      end

      c2t_done.receive
      t2c_done.receive
    end
  end
end