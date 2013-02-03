require 'celluloid/io'

class EchoServer
  include Celluloid::IO

  def initialize(host, port)
    puts "*** Starting echo server on #{host}:#{port}"

    # Since we included Celluloid::IO, we're actually making a
    # Celluloid::IO::TCPServer here
    @server = TCPServer.new(host, port)
    async.run
  end

  finalizer :on_shutdown

  def on_shutdown
    @server.close if @server
  end

  def run
    loop { async.handle_connection @server.accept }
  end

  def handle_connection(socket)
    _, port, host = socket.peeraddr
    puts "*** Received connection from #{host}:#{port}"
    data = ""
    socket.write 'dumb server $ '
    loop {
      data << socket.readpartial(4096)
      #puts "read"+data.inspect
      offset = 0
      while data.index(/\x04|(?:.*\n)/, offset)
        line = $&.chomp
        offset += $&.length
        #puts "line:"+line.inspect
        case line
        when /\A\Z/
          ;
        when /\Aexit\Z/, /\x04/
          return
        when /\Aecho\s+(.*)\Z/
          socket.write "#{$1}\n"
        when /\Asleep\s+(.*)\Z/
          sleep $1.to_f
        else
          socket.write "invalid command: #{line}\n"
        end
        socket.write 'dumb server $ '
      end
      data = data[offset..-1]
    }
  rescue EOFError
    puts "*** #{host}:#{port} disconnected: "+ $!.to_s
  rescue Errno::ECONNRESET
    puts "*** #{host}:#{port} disconnected: "+ $!.to_s
  ensure
    socket.close
  end
end
