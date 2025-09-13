# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "./ogm/forwarder/**"

module OGM::Forwarder
  VERSION = "0.1.0"

  cfg = CLI.parse
  App.run(cfg)
end
