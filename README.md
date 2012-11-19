# RFC Websocket Client (rfc-ws-client)

A simple (more-or-less) RFC 6455 (Websocket) compatible client without external dependencies.

Currently doesn't support fragmentation.

Includes source code from [em-ws-client](https://github.com/dansimpson/em-ws-client) and [web-socket-ruby](https://github.com/gimite/web-socket-ruby).

## Installation

Add this line to your application's Gemfile:

    gem 'rfc-ws-client'

## Usage

```ruby
ws = RfcWebsocket::Websocket.new("wss://echo.websocket.org")
ws.send_message("test")
ws.receive # => "test"
ws.close
```

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
