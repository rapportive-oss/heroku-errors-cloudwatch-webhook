require 'sinatra'
require 'json'
require 'right_aws'

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
  log_per_app(events)
  log_per_app_and_error(events)
  log_per_app_and_dyno(events)
end

def log_per_app(events)
  events.group_by do |event|
    event['source_name'] || 'unknown'
  end.each do |app, events|
    puts "#{app}: #{events.size} events."

    $acw.put_metric_data({
      :metric_name => "Heroku errors",
      :namespace => CLOUDWATCH_NAMESPACE,
      :dimensions => {:AppName => app},
      :unit => :Count,
      :value => events.size,
    })
  end
end

def log_per_app_and_error(events)
  events.group_by do |event|
    message = event['message']
    app = event['source_name'] || 'unknown'
    if message
      [app, message[/^Error (\w+)/, 1] || 'other']
    else
      puts 'WARNING: event has no message!'
      nil
    end
  end.each do |(app, error), events|
    puts "#{app}: error #{error}: #{events.size} events."

    $acw.put_metric_data({
      :metric_name => "Heroku errors",
      :namespace => CLOUDWATCH_NAMESPACE,
      :dimensions => {:AppName => app, :ErrorCode => error},
      :unit => :Count,
      :value => events.size,
    })
  end
end

def log_per_app_and_dyno(events)
  events.group_by do |event|
    message = event['message']
    app = event['source_name'] || 'unknown'
    if message
      [app, message[/ dyno=web\.(\d+) /, 1] || 'platform']
    else
      puts 'WARNING: event has no message!'
      nil
    end
  end.each do |(app, dyno), events|
    puts "#{app}: dyno #{dyno}: #{events.size} events."

    $acw.put_metric_data({
      :metric_name => "Heroku errors",
      :namespace => CLOUDWATCH_NAMESPACE,
      :dimensions => {:AppName => app, :Dyno => dyno},
      :unit => :Count,
      :value => events.size,
    })
  end
end
