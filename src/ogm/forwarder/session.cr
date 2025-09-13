# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"
require "./config"

module OGM::Forwarder
  # Handles one downstream client connection and proxies to upstream.
  class Session
    def initialize(
      @client     : TCPSocket,
      @selector   : UpstreamSelector,
      @rw_timeout : Time::Span
    )
    end

    # Establish upstream and start bidirectional proxy.
    def run
      target = @selector.connect
      bidi_proxy(@client, target, @rw_timeout)
    rescue ex
      puts "Session error: #{ex.message}"
      @client.close rescue nil
    end

    private def bidi_proxy(client : TCPSocket, target : TCPSocket, rw_timeout : Time::Span)
      client.read_timeout  = rw_timeout
      client.write_timeout = rw_timeout
      target.read_timeout  = rw_timeout
      target.write_timeout = rw_timeout

      c2t_done = Channel(Nil).new
      t2c_done = Channel(Nil).new

      spawn do
        begin
          IO.copy(client, target)
        rescue ex
          puts "c→t ended: #{ex.message}"
        ensure
          target.close rescue nil
          c2t_done.send(nil)
        end
      end

      spawn do
        begin
          IO.copy(target, client)
        rescue ex
          puts "t→c ended: #{ex.message}"
        ensure
          client.close rescue nil
          t2c_done.send(nil)
        end
      end

      c2t_done.receive
      t2c_done.receive
    end
  end
end
