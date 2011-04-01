require 'sinatra'
require 'cgi'
require 'json'
require 'pp'

get '/' do
  'This is a web hook!'
end

post '/' do
  pp JSON.parse(CGI.unescape(request.body.read))
  'OK'
end
