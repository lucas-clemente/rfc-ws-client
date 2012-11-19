require "rfc-ws-client/version"

require "openssl"
require 'uri'
require 'socket'
require 'securerandom'
require "digest/sha1"
require 'rainbow'
require 'base64'

module RfcWebsocket
  class Websocket
    WEB_SOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    OPCODE_CONTINUATION = 0x00
    OPCODE_TEXT = 0x01
    OPCODE_BINARY = 0x02
    OPCODE_CLOSE = 0x08
    OPCODE_PING = 0x09
    OPCODE_PONG = 0x0a

    def initialize(uri, protocol = "")
      uri = URI.parse(uri) unless uri.is_a?(URI)
      @protocol = protocol
      path = (uri.path.empty? ? "/" : uri.path) + (uri.query ? "?" + uri.query : "")

      if uri.scheme == "ws"
        default_port = 80
      elsif uri.scheme = "wss"
        default_port = 443
      else
        raise "unsupported scheme: #{uri.scheme}"
      end

      @socket = TCPSocket.new(uri.host, uri.port || default_port)
      if uri.scheme == "wss"
        @socket = OpenSSL::SSL::SSLSocket.new(@socket)
        @socket.sync_close = true
        @socket.connect
      end

      request_key = SecureRandom::base64(16)
      write(handshake(uri.host, path, request_key))
      flush()

      status_line = gets.chomp
      raise "bad response: #{line}" unless status_line.start_with?("HTTP/1.1 101")

      header = {}
      while line = gets
        line.chomp!
        break if line.empty?
        if !(line =~ /\A(\S+): (.*)\z/n)
          raise "invalid response: #{line}"
        end
        header[$1.downcase] = $2
      end
      raise "upgrade missing" unless header["upgrade"]
      raise "connection missing" unless header["connection"]
      accept = header["sec-websocket-accept"]
      raise "sec-websocket-accept missing" unless accept
      expected_accept = Digest::SHA1.base64digest(request_key + WEB_SOCKET_GUID)
      raise "sec-websocket-accept is invalid, actual: #{accept}, expected: #{expected_accept}" unless accept == expected_accept

      @buffer = ""
      
    end

    def send_message
      
    end

    private

    def gets(delim = $/)
      line = @socket.gets(delim)
      print line.color(:green)
      line
    end

    def write(data)
      print data.color(:yellow)
      @socket.write(data)
    end

    def flush
      @socket.flush
    end

    def handshake(host, path, request_key)
      headers = ["GET #{path} HTTP/1.1"]
      headers << "Connection: keep-alive, Upgrade"
      headers << "Host: #{host}"
      headers << "Sec-WebSocket-Key: #{request_key}"
      headers << "Sec-WebSocket-Version: 13"
      headers << "Upgrade: websocket"
      headers << "User-Agent: rfc-ws-client"
      headers << "\r\n"
      headers.join "\r\n"
    end
  end
end
