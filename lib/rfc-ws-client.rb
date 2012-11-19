require "rfc-ws-client/version"

require "openssl"
require 'uri'
require 'socket'
require 'securerandom'
require "digest/sha1"
require 'rainbow'
require 'base64'

module RfcWebSocket
  class WebSocketError < RuntimeError
    attr_reader :code

    def initialize(text, code = 1002)
      super(text)
      @code = code
    end
  end

  class WebSocket
    WEB_SOCKET_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
    OPCODE_CONTINUATION = 0x00
    OPCODE_TEXT = 0x01
    OPCODE_BINARY = 0x02
    OPCODE_CLOSE = 0x08
    OPCODE_PING = 0x09
    OPCODE_PONG = 0x0a
    DEBUG = false

    def initialize(uri, protocol = "")
      uri = URI.parse(uri) unless uri.is_a?(URI)
      @protocol = protocol

      if uri.scheme == "ws"
        default_port = 80
      elsif uri.scheme = "wss"
        default_port = 443
      else
        raise WebSocketError.new("unsupported scheme: #{uri.scheme}")
      end
      host = uri.host + ((!uri.port || uri.port == default_port) ? "" : ":#{uri.port}")
      path = (uri.path.empty? ? "/" : uri.path) + (uri.query ? "?" + uri.query : "")

      @socket = TCPSocket.new(uri.host, uri.port || default_port)
      if uri.scheme == "wss"
        @socket = OpenSSL::SSL::SSLSocket.new(@socket)
        @socket.sync_close = true
        @socket.connect
      end

      request_key = SecureRandom::base64(16)
      write(handshake(host, path, request_key))
      flush()

      status_line = gets.chomp
      raise WebSocketError.new("bad response: #{status_line}") unless status_line.start_with?("HTTP/1.1 101")

      header = {}
      while line = gets
        line.chomp!
        break if line.empty?
        if !(line =~ /\A(\S+): (.*)\z/n)
          raise WebSocketError.new("invalid response: #{line}")
        end
        header[$1.downcase] = $2
      end
      raise WebSocketError.new("upgrade missing") unless header["upgrade"]
      raise WebSocketError.new("connection missing") unless header["connection"]
      accept = header["sec-websocket-accept"]
      raise WebSocketError.new("sec-websocket-accept missing") unless accept
      expected_accept = Digest::SHA1.base64digest(request_key + WEB_SOCKET_GUID)
      raise WebSocketError.new("sec-websocket-accept is invalid, actual: #{accept}, expected: #{expected_accept}") unless accept == expected_accept
    end

    def send_message(message, opts = {binary: false})
      write(encode(message, opts[:binary] ? OPCODE_BINARY : OPCODE_TEXT))
    end

    def receive
      begin
        buffer = ""
        fragmented = false
        binary = false
        # Loop until something returns
        while true
          b1, b2 = read(2).unpack("CC")
          puts "b1: #{b1.to_s(2).rjust(8, "0")}, b2: #{b2.to_s(2).rjust(8, "0")}" if DEBUG
          # first byte
          fin = (b1 & 0x80) != 0
          raise WebSocketError.new("reserved bits must be 0") if (b1 & 0b01110000) != 0
          opcode = b1 & 0x0f
          # second byte
          mask = (b2 & 0x80) != 0
          # we're a client
          raise WebSocketError.new("server->client must not be masked!") if mask
          length = b2 & 0x7f
          if opcode > 7
            raise WebSocketError.new("control frame cannot be fragmented") unless fin
            raise WebSocketError.new("control frame is too large: #{length}") if length > 125
            raise WebSocketError.new("unexpected reserved opcode: #{opcode}") if opcode > 0xA
            raise WebSocketError.new("close frame with payload length 1") if length == 1 and opcode == OPCODE_CLOSE
          elsif opcode != OPCODE_CONTINUATION && opcode != OPCODE_TEXT && opcode != OPCODE_BINARY
            raise WebSocketError.new("unexpected reserved opcode: #{opcode}")
          end
          # extended payload length
          if length == 126
            length = read(2).unpack("n")[0]
          elsif length == 127
            high, low = *read(8).unpack("NN")
            length = high * (2 ** 32) + low
          end
          # payload
          payload = read(length)
          case opcode
          when OPCODE_CONTINUATION
            raise WebSocketError.new("no frame to continue") unless fragmented
            buffer << payload.force_encoding("UTF-8")
            if fin
              raise WebSocketError.new("invalid utf8", 1007) if !binary and !valid_utf8?(buffer)
              return buffer, binary
            else
              next
            end
          when OPCODE_TEXT
            raise WebSocketError.new("unexpected opcode in continuation mode") if fragmented
            if !fin
              fragmented = true
              binary = false
              buffer << payload.force_encoding("UTF-8")
              next
            else
              raise WebSocketError.new("invalid utf8", 1007) unless valid_utf8?(payload)
              return payload, false
            end
          when OPCODE_BINARY
            raise WebSocketError.new("unexpected opcode in continuation mode") if fragmented
            if !fin
              fragmented = true
              binary = true
              buffer << payload
            else
              return payload, true
            end
          when OPCODE_CLOSE
            code, explain = payload.unpack("nA*")
            if explain && !valid_utf8?(explain)
              close(1007)
            else
              close(response_close_code(code))
            end
            return nil, nil
          when OPCODE_PING
            write(encode(payload, OPCODE_PONG))
            next
          when OPCODE_PONG
            next
          else
            raise WebSocketError.new("received unknown opcode: #{opcode}")
          end
        end
      rescue EOFError
        return nil, nil
      rescue WebSocketError => e
        puts e
        close(e.code)
        raise e
      end
    end

    def close(code = 1000, msg = nil)
      write(encode [code ? code : 1000, msg].pack("nA*"), OPCODE_CLOSE)
      @socket.close
    end

    private

    def gets(delim = $/)
      line = @socket.gets(delim)
      print line.color(:green) if DEBUG
      line
    end

    def write(data)
      print data.color(:yellow) if DEBUG
      @socket.write(data)
      @socket.flush
    end

    def read(num_bytes)
      str = @socket.read(num_bytes)
      if str && str.bytesize == num_bytes
        print str.color(:green) if DEBUG
        str
      else
        raise(EOFError)
      end
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

    def encode(data, opcode)
      raise WebSocketError.new("invalud utf8") if opcode == OPCODE_TEXT and !valid_utf8?(data)
      frame = [opcode | 0x80]
      packr = "CC"
      # append frame length and mask bit 0x80
      len = data ? data.bytesize : 0
      if len <= 125
        frame << (len | 0x80)
      elsif len < 65536
        frame << (126 | 0x80)
        frame << len
        packr << "n"
      else
        frame << (127 | 0x80)
        frame << len
        packr << "L!>"
      end
      # generate a masking key
      key = rand(2 ** 31)
      # mask each byte with the key
      frame << key
      packr << "N"
      # Apply the masking key to every byte
      len.times do |i|
        frame << ((data.getbyte(i) ^ (key >> ((3 - (i % 4)) * 8))) & 0xFF)
      end
      frame.pack("#{packr}C*")
    end

    def response_close_code(code)
      case code
      when 1000,1001,1002,1003,1007,1008,1009,1010,1011
        1000
      when 3000..3999
        1000
      when 4000..4999
        1000
      when nil
        1000
      else
        1002
      end
    end

    def force_utf8(str)
      str.force_encoding("UTF-8")
    end

    def valid_utf8?(str)
      force_utf8(str).valid_encoding?
    end
  end
end
