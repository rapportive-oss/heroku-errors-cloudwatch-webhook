require 'sinatra'
require 'cgi'
require 'json'
require 'pp'

get '/' do
  'This is a web hook!'
end

post '/' do
  payload = JSON.parse(params[:payload])
  #pp payload
  handle_payload(payload)
end

def handle_payload(payload)
  events = payload.delete('events') or raise 'No events!'
  pp payload
  puts "Got #{events.size} events!"
  events.group_by do |event|
    message = event['message']
    if message
      message[/^Error (\w+)/, 1]
    else
      puts 'WARNING: event has no message!'
      nil
    end
  end.each do |error, events|
    puts "Error #{error}: #{events.size} events."
  end

  'OK'
rescue => e
  [500, "#{e.class}: #{e}"]
end
