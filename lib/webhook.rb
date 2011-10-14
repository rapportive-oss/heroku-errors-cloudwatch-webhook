require 'sinatra'
require 'json'
require 'right_aws'

require 'analysis'
include Analysis

AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID'] or raise 'AWS_ACCESS_KEY_ID missing!'
AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY'] or raise 'AWS_SECRET_ACCESS_KEY missing!'
CLOUDWATCH_NAMESPACE = ENV['CLOUDWATCH_NAMESPACE'] || 'Test'

$acw = RightAws::AcwInterface.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

configure :production do
  require 'newrelic_rpm'
end

get '/' do
  'This is a web hook!'
end

post '/' do
  payload = JSON.parse(params[:payload])
  begin
    handle_payload(payload)
    'OK'
  rescue => e
    [500, "#{e.class}: #{e}"]
  end
end

def handle_payload(payload)
  events = payload.delete('events') or raise 'No events!'
  puts "Got #{events.size} events!"

  data = grouped_counts('Heroku errors', events,
    /^Error (\w+)/,
    :AppName => {:property => 'source_name', :default => 'unknown'},
    :ErrorCode => {:match => 1, :default => 'unknown'})

  $acw.put_metric_data({
    :namespace => CLOUDWATCH_NAMESPACE,
    :data => data,
  })
end

def grouped_counts(metric_name, events, *args)
  group_by_all_dimensions(events, *args).map do |dimensions, events|
    {
      :metric_name => metric_name,
      :dimensions => dimensions,
      :value => events.size,
      :unit => :Count,
    }
  end
end
