# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "./ogm/forwarder/**"

# OffgridMail Forwarder
#
# Accepts local client connections and forwards traffic
# to a primary or backup upstream server. Designed for
# low-bandwidth and offline-capable environments.
#
# Usage:
#   require "offgridmail-forwarder"
#   OGM::Forwarder::App.run(OGM::Forwarder::CLI.parse)
#
# See architecture notes: design/ARCHITECTURE.md
module OGM::Forwarder
  # Current library version.
  VERSION = "0.1.0"

  cfg = CLI.parse
  App.run(cfg)
end
