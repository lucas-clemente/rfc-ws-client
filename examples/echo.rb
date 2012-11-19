$: << File.dirname(__FILE__) + "/../lib"

require "rfc-ws-client"

ws = RfcWebsocket::Websocket.new("ws://echo.websocket.org")
