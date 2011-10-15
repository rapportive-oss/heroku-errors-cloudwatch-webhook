require 'sinatra'
require 'json'
require 'right_aws'

require 'analysis'
include Analysis

MAX_DATA_PER_CALL = (ENV['MAX_DATA_PER_CALL'] || 20).to_i

AWS_ACCESS_KEY_ID = ENV['AWS_ACCESS_KEY_ID'] or raise 'AWS_ACCESS_KEY_ID missing!'
AWS_SECRET_ACCESS_KEY = ENV['AWS_SECRET_ACCESS_KEY'] or raise 'AWS_SECRET_ACCESS_KEY missing!'
CLOUDWATCH_NAMESPACE = ENV['CLOUDWATCH_NAMESPACE'] || 'Test'

$acw = RightAws::AcwInterface.new(AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

configure :production do
  require 'newrelic_rpm'
  require 'airbrake'

  Airbrake.configure do |config|
    config.api_key = ENV['AIRBRAKE_API_KEY']
  end
  use Airbrake::Rack
  enable :raise_errors
end

get '/' do
  'This is a web hook!'
end

post '/:metric_name' do |metric_name|
  payload = JSON.parse(params[:payload])
  if params[:regex]
    regex = Regexp.compile(params[:regex])
    puts "Regex: #{regex.inspect}"
  end
  dimensions = params[:dimensions].map {|group, dimension| [group.to_i, dimension.to_sym] } if params[:dimensions]
  events_to_cloudwatch(metric_name, regex, dimensions, payload)
  'OK'
end

def events_to_cloudwatch(metric_name, regex, dimension_groups, payload)
  events = payload.delete('events') or raise 'No events!'
  puts "Got #{events.size} events!"

  raise ArgumentError, "Can't have :dimensions with no :regex!" if dimension_groups && !regex

  dimensions = {
    :AppName => {:property => 'source_name', :default => 'unknown'},
  }
  (dimension_groups || []).each do |group, dimension|
    dimensions[dimension] = {:match => group, :default => 'unknown'}
  end

  grouped_counts(metric_name, events, regex, dimensions).each_slice(MAX_DATA_PER_CALL) do |data|
    # each_slice because Cloudwatch has a maximum number of data points it will
    # accept per PutMetricData call
    $acw.put_metric_data({
      :namespace => CLOUDWATCH_NAMESPACE,
      :data => data,
    })
  end
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
