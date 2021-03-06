module SocketHarness
  class Proxy
    BLOCK_SIZE = 1024

    def self.default_options
      {
        :local_port => 13012,
        :block_size => 1024,
        :delay => 0,
      }
    end

    def initialize(remote_host, remote_port, options={})
      @remote_host = remote_host
      @remote_port = remote_port
      @options = self.class.default_options.merge(options)
    end

    def run
      puts "*** target #{@remote_host}:#{@remote_port}"
      server = TCPServer.open(@options[:local_host], @options[:local_port].to_i)

      port = server.addr[1]
      addrs = server.addr[2..-1].uniq

      puts "*** listening on #{addrs.collect{|a|"#{a}:#{port}"}.join(' ')}"

      # abort on exceptions, otherwise threads will be silently killed in case
      # of unhandled exceptions
      Thread.abort_on_exception = true

      # have a thread just to process Ctrl-C events on Windows
      # (although Ctrl-Break always works)
      Thread.new { loop { sleep 1 } }
      loop do
        # whenever server.accept returns a new connection, start
        # a handler thread for that connection
        Thread.start(server.accept) { |local| conn_thread(local) }
      end
    end

    private

    def conn_thread(local)
      port, name = local.peeraddr[1..2]
      puts "*** receiving from #{name}:#{port}"

      # open connection to remote server
      remote = TCPSocket.new(@remote_host, @remote_port)

      # start reading from both ends
      loop do
        ready = select([local, remote], nil, nil)
        if ready[0].include? local
          # local -> remote
          data = local.recv(@options[:block_size])
          if data.empty?
            puts "local end closed connection"
            break
          end
          puts "#{name}:#{port} -{}-> #{@remote_host}:#{@remote_port} #{data.size} byte ..."
          remote.write(data)
        end
        if ready[0].include? remote
          # remote -&gt; local
          data = remote.recv(@options[:block_size])
          if data.empty?
            puts "remote end closed connection"
            break
          end
          puts "#{@remote_host}:#{@remote_port} -{#{delay}ms}-> #{name}:#{port}  #{data.size} byte ..."
          sleep delay * 1.0 / 1000.0
          local.write(data)
        end
      end

      local.close
      remote.close

      puts "*** done with #{name}:#{port}"
    end

    def delay
      @options[:delay].to_i
    end
  end
end
