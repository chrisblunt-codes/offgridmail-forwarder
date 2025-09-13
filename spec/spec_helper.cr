# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "spec"

# Require only the library parts, not the runner.
require "../src/ogm/forwarder/config"
require "../src/ogm/forwarder/cli"
require "../src/ogm/forwarder/upstream_selector"
require "../src/ogm/forwarder/session"
require "../src/ogm/forwarder/listener"

require "./support/echo_server"