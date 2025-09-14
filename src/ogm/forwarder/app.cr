# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

require "./config"
require "./upstream_selector"
require "./listener"

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
      Log.setup do |c|
        c.bind "*", level: cfg.log_level, backend: Log::IOBackend.new(STDERR)
      end

      upstream  = case cfg.upstream_mode
                  when UpstreamMode::Tcp
                    UpstreamSelector.new(cfg)  # TCP failover (primary → backup)
                  when UpstreamMode::Serial
                    SerialUpstream.new(cfg.serial_dev, cfg.serial_baud)
                  end

      listener = Listener.new(cfg, upstream.not_nil!)

      Signal::INT.trap  { puts "→ SIGINT received, shutting down…";  listener.stop }
      Signal::TERM.trap { puts "→ SIGTERM received, shutting down…"; listener.stop }

      listener.run
      # after accept loop exits, wait for a short drain period
      listener.wait_for_drain(10.seconds)
      Log.info { "Shutdown complete." }
    end
  end
end