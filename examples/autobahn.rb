$: << File.dirname(__FILE__) + "/../lib"

require "rfc-ws-client"

ws = RfcWebSocket::WebSocket.new("ws://localhost:9001/getCaseCount")
count = ws.receive()[0].to_i
ws.close

(1..count).each do |i|
  puts "#{i}/#{count}"
  begin
    ws = RfcWebSocket::WebSocket.new "ws://localhost:9001/runCase?&case=#{i}&agent=rfc-ws-client"
    while true
      data, binary = ws.receive
      break if data.nil?
      ws.send_message data, binary: binary
    end
  rescue => e
    puts e
  end
end

puts "Updating reports and shutting down"
ws = RfcWebSocket::WebSocket.new "ws://localhost:9001/updateReports?agent=rfc-ws-client"
ws.receive
