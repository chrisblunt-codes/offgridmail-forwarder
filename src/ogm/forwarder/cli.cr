# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "log"
require "option_parser"

require "./config"

module OGM::Forwarder
  module CLI
    # Parses environment variables and command-line flags
    # and returns a Config instance.
    #
    # Defaults are taken from ENV, then overridden by any
    # CLI arguments provided in `argv`.
    def self.parse(argv = ARGV) : Config
      listen_host = ENV["LISTEN_HOST"]?  || "127.0.0.1"
      listen_port = (ENV["LISTEN_PORT"]? || "2525").to_i

      primary_s = (ENV["PRIMARY"]? || "mailserver1.example.com:25")
      backup_s  = (ENV["BACKUP"]?  || "mailserver2.example.com:25")

      connect_timeout = (ENV["CONNECT_TIMEOUT"]? || "5").to_i.seconds
      rw_timeout      = (ENV["RW_TIMEOUT"]?      || "120").to_i.seconds

      # default log level (env LOG_LEVEL=debug|info|warn|error|fatal optional)
      log_level = parse_level(ENV["LOG_LEVEL"]?) || Log::Severity::Info

      # upstream mode + serial opts
      mode_s      = ENV["UPSTREAM_MODE"]? || "tcp"         # tcp|serial
      serial_dev  = ENV["SERIAL_DEV"]?    || "/dev/ttyUSB0"
      serial_baud = (ENV["SERIAL_BAUD"]?  || "115200").to_i

      OptionParser.parse(argv) do |p|
        p.banner = "Usage: ogm_forwarder [options]"

        p.on("-l HOST", "--listen HOST", "Listen host (or LISTEN_HOST)") { |v| listen_host = v }
        p.on("-p PORT", "--port PORT",   "Listen port (or LISTEN_PORT)") { |v| listen_port = v.to_i }
        p.on("--primary HOST:PORT", "Primary upstream (or PRIMARY)")     { |v| primary_s = v }
        p.on("--backup HOST:PORT",  "Backup upstream  (or BACKUP)")      { |v| backup_s  = v }

        p.on("--mode MODE", "Upstream mode: tcp|serial (or UPSTREAM_MODE)") { |v| mode_s = v }
        p.on("--serial-dev PATH", "Serial device path (or SERIAL_DEV)")     { |v| serial_dev = v }
        p.on("--serial-baud N",   "Serial baud rate (or SERIAL_BAUD)")      { |v| serial_baud = v.to_i }

        p.on("-v", "--verbose", "Verbose logging (DEBUG)") { log_level = Log::Severity::Debug }
        p.on("-q", "--quiet",   "Quiet logging (WARN)")    { log_level = Log::Severity::Warn }
        p.on("--silent",        "Minimal logging (ERROR)") { log_level = Log::Severity::Error }

        p.on("-h", "--help", "Show help") { puts p; exit 0 }
      end

      mode  = case mode_s.downcase
              when "tcp"    then UpstreamMode::Tcp
              when "serial" then UpstreamMode::Serial
              else
                STDERR.puts "Unknown mode '#{mode_s}', expected tcp|serial"; exit 2
              end

      Config.new(
        listen_host:      listen_host,
        listen_port:      listen_port,
        primary:          HostPort.parse(primary_s),
        backup:           HostPort.parse(backup_s),
        connect_timeout:  connect_timeout,
        rw_timeout:       rw_timeout,
        log_level:        log_level,
        upstream_mode:    mode,
        serial_dev:       serial_dev,
        serial_baud:      serial_baud
      )
    end

    private def self.parse_level(s : String?) : Log::Severity?
      return nil unless s

      case s.downcase
      when "debug" then Log::Severity::Debug
      when "info"  then Log::Severity::Info
      when "warn","warning" then Log::Severity::Warn
      when "error" then Log::Severity::Error
      when "fatal" then Log::Severity::Fatal
      else nil
      end
    end
  end
end
