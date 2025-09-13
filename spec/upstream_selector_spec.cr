# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "./spec_helper"

describe OGM::Forwarder::UpstreamSelector do
  it "prefers primary when available, falls back when not" do
    # primary up
    primary = EchoServer.new
    backup  = EchoServer.new

    cfg = OGM::Forwarder::Config.new(
      listen_host: "127.0.0.1", listen_port: 0,
      primary: OGM::Forwarder::HostPort.new(primary.host, primary.port),
      backup:  OGM::Forwarder::HostPort.new(backup.host, backup.port),
      connect_timeout: 1.seconds, rw_timeout: 1.seconds,
      log_level: Log::Severity::Error
    )
    
    sel = OGM::Forwarder::UpstreamSelector.new(cfg)
    s = sel.connect
    s.remote_address.port.should eq primary.port
    s.close

    # primary down -> fallback
    primary.close
    s2 = sel.connect
    s2.remote_address.port.should eq backup.port
    s2.close

    backup.close
  end
end
