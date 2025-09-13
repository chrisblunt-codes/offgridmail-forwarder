# Copyright 2025 Chris Blunt
# Licensed under the Apache License, Version 2.0

require "socket"

# Tiny TCP echo server for tests
class EchoServer
  getter host : String
  getter port : Int32

  @server : TCPServer
  @running = Atomic(Bool).new(true)

  def initialize(@host = "127.0.0.1", port = 0)
    @server = TCPServer.new(host, port) # port 0 => ephemeral
    @port   = @server.local_address.port
    
    spawn { accept_loop }
  end

  private def accept_loop
    while @running.get
      begin
        if sock = @server.accept?
          spawn handle(sock)   # pass TCPSocket, not (TCPSocket|Nil)
        end
      rescue IO::Error
        break
      end
    end
  end

  private def handle(sock : TCPSocket)
    begin
      IO.copy(sock, sock)   # echo
    rescue
    ensure
      sock.close rescue nil
    end
  end
  
  def close
    return unless @running.swap(false)
    @server.close rescue nil
  end
end
