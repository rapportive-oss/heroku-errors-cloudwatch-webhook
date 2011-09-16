# Monitor Heroku Errors in CloudWatch

This is a web hook designed to receive
[Heroku platform errors](http://devcenter.heroku.com/articles/error-codes) from
a logging service such as [Papertrail](https://papertrailapp.com) and log them
to [Amazon CloudWatch](http://aws.amazon.com/cloudwatch/) so you can monitor
and graph the number of occurrences of each type of error over time.


## Requirements

Tested under Ruby 1.9.2.


## Running locally

To test this hook locally:

    gem install bundler foreman
    bundle install
    echo AWS_ACCESS_KEY_ID=[your AWS access key ID] > .env
    echo AWS_SECRET_ACCESS_KEY=[your AWS secret access key] > .env
    echo CLOUDWATCH_NAMESPACE=[optional namespace || 'Test'] > .env
    foreman start


## Deploying

This runs nicely on Heroku's
[Cedar stack](http://devcenter.heroku.com/articles/cedar):

    heroku create --stack cedar
    heroku config:add AWS_ACCESS_KEY_ID=[your AWS access key ID]
    heroku config:add AWS_SECRET_ACCESS_KEY=[your AWS secret access key]
    heroku config:add CLOUDWATCH_NAMESPACE=[optional namespace || 'Test']
    git push heroku master

Then the web hook URL is `https://your-app-name.herokuapp.com/`.


## Log input format

The web hook expects to receive POST requests to '/' in the format described
[here](http://help.papertrailapp.com/kb/how-it-works/web-hooks).

It assumes it will only be sent Heroku error messages, which look like this:

    Error H12 (Request timeout) -> GET yourapp.herokuapp.com/url dyno=web.13 queue= wait= service=30000ms status=503 bytes=0

If instead you simply send it *all* your logs, it will treat log entries not in
this format as unclassified errors, so you will see a large number of errors
with error code "other".

If you're triggering this hook from a Papertrail search alert, a search pattern
such as `heroku/router Error "->"` is restrictive enough to catch the right
log entries.


## CloudWatch output

The web hook will aggregate errors by Heroku error code and log them as
CloudWatch custom metrics.  You can then use the CloudWatch console to produce
graphs like this:

![Example error graph in CloudWatch console](http://pix.samstokes.s3.amazonaws.com/heroku-errors-cloudwatch-screenshot.png)
