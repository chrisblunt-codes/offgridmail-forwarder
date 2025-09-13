# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"

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
      selector = UpstreamSelector.new(cfg)
      Listener.new(cfg, selector).run
    end
  end
end