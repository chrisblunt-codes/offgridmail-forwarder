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

      OptionParser.parse(argv) do |parser|
        parser.banner = "Usage: ogm_forwarder [options]\n" \
                        "  --primary host:port  Primary upstream\n" \
                        "  --backup  host:port  Backup  upstream\n" \
                        "  -l, --listen HOST    Listen host (default 127.0.0.1)\n" \
                        "  -p, --port PORT      Listen port (default 2525 or LISTEN_PORT)\n"

        parser.on("-l HOST", "--listen HOST", "Listen host") { |v| listen_host = v }
        parser.on("-p PORT", "--port PORT",   "Listen port") { |v| listen_port = v.to_i }
        parser.on("--primary HOST:PORT", "Primary upstream") { |v| primary_s = v }
        parser.on("--backup HOST:PORT",  "Backup upstream")  { |v| backup_s  = v }

        parser.on("-v", "--verbose", "Verbose logging (DEBUG)") { log_level = Log::Severity::Debug }
        parser.on("-q", "--quiet",   "Quiet logging (WARN)")    { log_level = Log::Severity::Warn }
        parser.on("--silent",        "Minimal logging (ERROR)") { log_level = Log::Severity::Error }

        parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
      end

      Config.new(
        listen_host:      listen_host,
        listen_port:      listen_port,
        primary:          HostPort.parse(primary_s),
        backup:           HostPort.parse(backup_s),
        connect_timeout:  connect_timeout,
        rw_timeout:       rw_timeout,
        log_level:        log_level
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
