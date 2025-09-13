# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "./ogm/forwarder/**"

module OGM::Forwarder; end

cfg = OGM::Forwarder::CLI.parse
OGM::Forwarder::App.run(cfg)