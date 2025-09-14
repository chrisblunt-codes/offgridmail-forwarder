# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

require "./config"
require "./listener"
require "./serial_pump"
require "./serial_upstream"
require "./upstream_selector"

module OGM::Forwarder
  module App
    def self.run(cfg : Config)
      Log.setup { |c| c.bind "*", level: cfg.log_level, backend: Log::IOBackend.new(STDERR) }

      if cfg.role.listener?
        # Listener: downstream TCP → upstream (TCP or Serial per config)
        upstream = case cfg.upstream_mode
                   when UpstreamMode::Tcp
                     UpstreamSelector.new(cfg)                  # primary → backup
                   when UpstreamMode::Serial
                     SerialUpstream.new(cfg.serial_dev, cfg.serial_baud)
                   end

        listener = Listener.new(cfg, upstream.not_nil!)
        Signal::INT.trap  { Log.info { "SIGINT received, shutting down…" };  listener.stop }
        Signal::TERM.trap { Log.info { "SIGTERM received, shutting down…" }; listener.stop }

        listener.run
        listener.wait_for_drain(10.seconds)
        Log.info { "Shutdown complete." }

      else # Role::Pump
        # Pump: local serial ↔ remote TCP (failover)
        tcp_upstream = UpstreamSelector.new(cfg) # always TCP here
        pump = SerialTcpPump.new(cfg.serial_dev, cfg.serial_baud, tcp_upstream, cfg.rw_timeout)

        Signal::INT.trap  { Log.info { "SIGINT received, stopping pump…" };  pump.stop }
        Signal::TERM.trap { Log.info { "SIGTERM received, stopping pump…" }; pump.stop }

        pump.run
      end
    end
  end
end
