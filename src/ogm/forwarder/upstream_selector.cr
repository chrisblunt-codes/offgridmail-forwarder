# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"
require "socket"

require "./config"
require "./upstream"

module OGM::Forwarder
  # TCP upstream with primary→backup failover.
  class UpstreamSelector
    include Upstream

    getter cfg : Config

    def initialize(@cfg : Config)
    end

    # Connect to primary first; fallback to backup on failure.
    def connect : IO
      begin
        sock = TCPSocket.new(cfg.primary.host, cfg.primary.port,
                             connect_timeout: cfg.connect_timeout)
        Log.info { "Using PRIMARY #{cfg.primary}" }
        return sock
      rescue ex
        Log.warn { "Primary failed: #{ex.message}" }
      end

      sock = TCPSocket.new(cfg.backup.host, cfg.backup.port,
                           connect_timeout: cfg.connect_timeout)
      Log.info { "Using BACKUP #{cfg.backup}" }
      sock
    end
  end
end
