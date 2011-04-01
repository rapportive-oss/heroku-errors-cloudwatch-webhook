require 'sinatra'
get '/' do
  'This is a web hook!'
end

post '/' do
  puts request.body.read
  'OK'
end
