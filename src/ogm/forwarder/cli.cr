# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"
require "option_parser"

require "./config"

module OGM::Forwarder
  module CLI
    def self.parse(argv = ARGV) : Config
      cfg = env_defaults

      OptionParser.parse(argv) do |p|
        p.banner = "Usage: ogm_forwarder [options]"

        p.on("-l HOST", "--listen HOST", "Listen host (or LISTEN_HOST)") { |v| cfg = cfg.with(listen_host: v) }
        p.on("-p PORT", "--port PORT",   "Listen port (or LISTEN_PORT)") { |v| cfg = cfg.with(listen_port: v.to_i) }

        p.on("--primary HOST:PORT", "Primary upstream (or PRIMARY)") { |v| cfg = cfg.with(primary: HostPort.parse(v)) }
        p.on("--backup HOST:PORT",  "Backup upstream  (or BACKUP)")  { |v| cfg = cfg.with(backup:  HostPort.parse(v)) }

        p.on("--mode MODE", "Upstream mode: tcp|serial (or UPSTREAM_MODE)") { |v| cfg = cfg.with(upstream_mode: parse_mode(v)) }
        p.on("--serial-dev PATH", "Serial device path (or SERIAL_DEV)")     { |v| cfg = cfg.with(serial_dev: v) }
        p.on("--serial-baud N",   "Serial baud rate (or SERIAL_BAUD)")      { |v| cfg = cfg.with(serial_baud: v.to_i) }

        p.on("--role ROLE", "listener|pump (or ROLE)") { |v| cfg = cfg.with(role: parse_role(v)) }

        p.on("-v", "--verbose", "Verbose logging (DEBUG)") { cfg = cfg.with(log_level: Log::Severity::Debug) }
        p.on("-q", "--quiet",   "Quiet logging (WARN)")    { cfg = cfg.with(log_level: Log::Severity::Warn) }
        p.on("--silent",        "Minimal logging (ERROR)") { cfg = cfg.with(log_level: Log::Severity::Error) }

        p.on("-h", "--help", "Show help") { puts p; exit 0 }
      end

      cfg
    end

    # --- helpers -------------------------------------------------------------

    private def self.env_defaults : Config
      role_s      = ENV["ROLE"]?            || "listener"
      listen_host = ENV["LISTEN_HOST"]?     || "127.0.0.1"
      listen_port = (ENV["LISTEN_PORT"]?    || "2525").to_i

      primary_s   = ENV["PRIMARY"]?         || "mailserver1.example.com:25"
      backup_s    = ENV["BACKUP"]?          || "mailserver2.example.com:25"

      connect_to  = (ENV["CONNECT_TIMEOUT"]?|| "5").to_i.seconds
      rw_to       = (ENV["RW_TIMEOUT"]?     || "120").to_i.seconds

      level_s     = ENV["LOG_LEVEL"]?
      mode_s      = ENV["UPSTREAM_MODE"]?   || "tcp"
      serial_dev  = ENV["SERIAL_DEV"]?      || "/dev/ttyUSB0"
      serial_baud = (ENV["SERIAL_BAUD"]?    || "115200").to_i

      Config.new(
        role:            parse_role(role_s),
        listen_host:     listen_host,
        listen_port:     listen_port,
        primary:         HostPort.parse(primary_s),
        backup:          HostPort.parse(backup_s),
        connect_timeout: connect_to,
        rw_timeout:      rw_to,
        log_level:       parse_level(level_s) || Log::Severity::Info,
        upstream_mode:   parse_mode(mode_s),
        serial_dev:      serial_dev,
        serial_baud:     serial_baud,
      )
    end

    private def self.parse_mode(s : String) : UpstreamMode
      case s.downcase
      when "tcp"    then UpstreamMode::Tcp
      when "serial" then UpstreamMode::Serial
      else
        STDERR.puts "Unknown mode '#{s}', expected tcp|serial"; exit 2
      end
    end

    private def self.parse_role(s : String) : Role
      s.downcase == "pump" ? Role::Pump : Role::Listener
    end

    private def self.parse_level(s : String?) : Log::Severity?
      return nil unless s
      case s.downcase
      when "debug"            then Log::Severity::Debug
      when "info"             then Log::Severity::Info
      when "warn", "warning"  then Log::Severity::Warn
      when "error"            then Log::Severity::Error
      when "fatal"            then Log::Severity::Fatal
      else nil
      end
    end
  end
end
