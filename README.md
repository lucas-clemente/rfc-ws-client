# RFC WebSocket Client (rfc-ws-client)

A simple RFC 6455 compatible client without external dependencies.

Includes source code from [em-ws-client](https://github.com/dansimpson/em-ws-client) and [web-socket-ruby](https://github.com/gimite/web-socket-ruby).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'rfc-ws-client'
```

## Usage

```ruby
ws = RfcWebSocket::WebSocket.new("wss://echo.websocket.org")
ws.send_message("test", binary: false)
msg, binary = ws.receive # => "test", false
ws.close
```

## Testing

```bash
    wstest -m fuzzingserver
    # in different console
    ruby examples/autobahn.rb
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
