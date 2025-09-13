# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"

require "./config"
require "./session"
require "./upstream_selector"

module OGM::Forwarder
  # Accept loop: creates a Session per client and runs it in a fiber.
  class Listener
    @server : TCPServer? = nil
    @stopping = false

    def initialize(@cfg : Config, @selector : UpstreamSelector)
    end

    def run
      @server = TCPServer.new(@cfg.listen_host, @cfg.listen_port)
      puts "Listening on #{@cfg.listen_host}:#{@cfg.listen_port} " \
           "(primary: #{@cfg.primary}, backup: #{@cfg.backup})"

      loop do
        break if @stopping

        begin
          client = @server.not_nil!.accept
        rescue ex : IO::Error
          # If we're stopping, accept() will raise because the server is closed.
          break if @stopping
          raise ex
        end

        spawn do
          Session.new(client, @selector, @cfg.rw_timeout).run
        end
      ensure
        @server.try &.close
      end
    end

    # Stop accepting new clients; existing sessions will drain naturally.
    def stop
      @stopping = true
      @server.try { |s| s.close rescue nil }
    end
  end
end
