source :rubygems
gem 'rack'
gem 'sinatra'
gem 'json'
gem 'right_aws', :git => 'git://github.com/rapportive-oss/right_aws.git'

group :production do
  gem 'newrelic_rpm'
  gem 'airbrake'
  gem 'i18n' # don't actually need it, but airbrake needs activesupport which needs it
end

group :test do
  gem 'rspec'
end
