# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

module OGM::Forwarder
  module Upstream
    abstract def connect : IO
  end
end

