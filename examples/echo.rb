$: << File.dirname(__FILE__) + "/../lib"

require "rfc-ws-client"

# ws = RfcWebsocket::Websocket.new("ws://echo.websocket.org")
# ws.send_message("blub", binary: true)
# puts "sent blub"
# answer = ws.receive[0]
# puts "answer: #{answer}"
# ws.close

ws = RfcWebsocket::Websocket.new("ws://localhost:9001/getCaseCount")
count = ws.receive()[0].to_i
ws.close

(1..count).each do |i|
  puts "#{i}/#{count}"
  begin
    ws = RfcWebsocket::Websocket.new "ws://localhost:9001/runCase?&case=#{i}&agent=rfc-ws-client"
    while true
      data, binary = ws.receive
      break if binary.nil?
      ws.send_message data, binary: binary
    end
  rescue
  end
end

puts "Updating reports and shutting down"
ws = RfcWebsocket::Websocket.new "ws://localhost:9001/updateReports?agent=rfc-ws-client"
ws.receive
