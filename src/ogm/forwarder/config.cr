# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"

module OGM::Forwarder
  # Supported upstream modes
  enum UpstreamMode
    Tcp
    Serial
  end
  
  # Supported roles (Listener - TCP or Pump - Serial)
  enum Role
    Listener
    Pump
  end

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
    getter role             : Role
    getter listen_host      : String
    getter listen_port      : Int32
    getter primary          : HostPort
    getter backup           : HostPort
    getter connect_timeout  : Time::Span
    getter rw_timeout       : Time::Span
    getter log_level        : Log::Severity
    getter upstream_mode    : UpstreamMode
    getter serial_dev       : String
    getter serial_baud      : Int32

    def initialize(
      @role                 : Role,
      @listen_host          : String,
      @listen_port          : Int32,
      @primary              : HostPort,
      @backup               : HostPort,
      @connect_timeout      : Time::Span,
      @rw_timeout           : Time::Span,
      @log_level            : Log::Severity,
      @upstream_mode        : UpstreamMode,
      @serial_dev           : String,
      @serial_baud          : Int32
    ); end

    # --- copy-with override ---------------------------------------------------
    def with(
      role            : Role? = nil,
      listen_host     : String? = nil,
      listen_port     : Int32? = nil,
      primary         : HostPort? = nil,
      backup          : HostPort? = nil,
      connect_timeout : Time::Span? = nil,
      rw_timeout      : Time::Span? = nil,
      log_level       : Log::Severity? = nil,
      upstream_mode   : UpstreamMode? = nil,
      serial_dev      : String? = nil,
      serial_baud     : Int32? = nil
    ) : Config
      Config.new(
        role             || @role,
        listen_host      || @listen_host,
        listen_port      || @listen_port,
        primary          || @primary,
        backup           || @backup,
        connect_timeout  || @connect_timeout,
        rw_timeout       || @rw_timeout,
        log_level        || @log_level,
        upstream_mode    || @upstream_mode,
        serial_dev       || @serial_dev,
        serial_baud      || @serial_baud,
      )
    end
  end
end
