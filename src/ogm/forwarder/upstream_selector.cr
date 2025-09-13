# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"
require "./config"

module OGM::Forwarder
  # Chooses and opens an upstream connection (primary → backup).
  class UpstreamSelector
    getter cfg : Config

    def initialize(@cfg : Config)
    end

    # Connect to primary first; fallback to backup on failure.
    def connect : TCPSocket
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
  end
end
