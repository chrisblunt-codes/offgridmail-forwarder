# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"

require "./config"
require "./session"
require "./upstream_selector"

module OGM::Forwarder
  # Accept loop: creates a Session per client and runs it in a fiber.
  class Listener
    def initialize(@cfg : Config, @selector : UpstreamSelector)
    end

    def run
      server = TCPServer.new(@cfg.listen_host, @cfg.listen_port)
      puts "Listening on #{@cfg.listen_host}:#{@cfg.listen_port} " \
           "(primary: #{@cfg.primary}, backup: #{@cfg.backup})"

      loop do
        client = server.accept
        spawn do
          Session.new(client, @selector, @cfg.rw_timeout).run
        end
      end
    end
  end
end
