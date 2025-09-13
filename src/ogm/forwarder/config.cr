# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

module OGM::Forwarder
  # Represents a host/port pair (e.g. "mail.example.com:25").
  #
  # Parsed from ENV or CLI and used for connecting to upstream servers.
  struct HostPort
    getter host : String
    getter port : Int32

    def initialize(@host : String, @port : Int32); end

    def self.parse(hp : String) : HostPort
      host, port = hp.split(":", 2)
      HostPort.new(host, port.to_i)
    end

    def to_s : String
      "#{host}:#{port}"
    end
  end

  # Config stores all runtime settings
  
  # Collected from ENV and CLI.
  struct Config
    getter listen_host      : String
    getter listen_port      : Int32
    getter primary          : HostPort
    getter backup           : HostPort
    getter connect_timeout  : Time::Span
    getter rw_timeout       : Time::Span
    getter log_level        : Log::Severity

    def initialize(
      @listen_host          : String,
      @listen_port          : Int32,
      @primary              : HostPort,
      @backup               : HostPort,
      @connect_timeout      : Time::Span,
      @rw_timeout           : Time::Span,
      @log_level            : Log::Severity
    ); end
  end
end
