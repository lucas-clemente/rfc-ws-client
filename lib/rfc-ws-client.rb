require "rfc-ws-client/version"

module RfcWebsocket
  class Websocket
    def initialize(params = {})
      throw "no host provided" unless params[:host]
      params[:port] ||= params[:host].starts_with?("wss") ? 433 : 80
      params[:protocol] ||= ""

    end

    def receive
      
    end

    def send_message
      
    end
  end
end
