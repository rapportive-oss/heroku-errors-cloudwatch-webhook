require 'analysis'

describe Analysis do
  include Analysis

  def fake_event(properties = {})
    properties = properties.dup
    except = Array(properties.delete(:except))

    # example event borrowed from
    # http://help.papertrailapp.com/kb/how-it-works/web-hooks
    {
      "hostname" => "abc",
      "received_at" => "2011-05-18T20:30:02-07:00",
      "severity" => "Info",
      "facility" => "Cron",
      "source_id" => 2,
      "message" => "message body",
      "program" => "CROND",
      "source_ip" => "208.75.57.121",
      "display_received_at" => "May 18 20:30:02",
      "id" => 7711561783320576,
      "source_name" => "abc",
    }.merge(properties).reject {|property, _| except.member?(property) }
  end


  describe 'counting events' do
    def events
      [
        {'source_name' => 'Alderaan'},
        {'source_name' => 'Coruscant'},
        {'source_name' => 'Alderaan'},
        {},
      ]
    end

    it 'should group the events by the declared dimensions' do
      grouped_events = group_by_dimensions(events,
        :AppName => {:property => 'source_name', :default => 'unknown'})
      grouped_events = Hash[*grouped_events.flatten]

      grouped_events.should have(3).groups
      grouped_events[{:AppName => 'Alderaan'}].should have(2).events
      grouped_events[{:AppName => 'Coruscant'}].should have(1).event
      grouped_events[{:AppName => 'unknown'}].should have(1).event
    end
  end


  describe :event_dimensions do
    describe 'dimension declarations' do
      describe 'event properties' do
        it 'should have the named event property as the dimension value' do
          event_dimensions(fake_event,
                           :AppName => {:property => 'source_name'})[:AppName].should == 'abc'
        end

        it 'should use the default if property is missing' do
          event_dimensions(fake_event(:except => 'source_name'),
                           :AppName => {
                             :property => 'source_name',
                             :default => 'unknown'})[:AppName].should == 'unknown'
        end
      end

      describe 'message parsing' do
        it 'should match the regex against the message and use the specified capturing group as the dimension value' do
          event_dimensions(fake_event('message' => 'Error H12 in /blah/blah'),
                           /^Error (\w+)/,
                           :ErrorCode => {:match => 1})[:ErrorCode].should == 'H12'
        end

        it 'should use the default if message is missing' do
          event_dimensions(fake_event(:except => 'message'),
                           /^Error (\w+)/,
                           :ErrorCode => {
                             :match => 1,
                             :default => 'unknown'})[:ErrorCode].should == 'unknown'
        end

        it 'should use the default if message does not match regex' do
          event_dimensions(fake_event('message' => 'Your face is an error'),
                           /^Error (\w+)/,
                           :ErrorCode => {
                             :match => 1,
                             :default => 'unknown'})[:ErrorCode].should == 'unknown'
        end

        it 'should use the default if group does not capture anything' do
          event_dimensions(fake_event('message' => 'Error'),
                           /^Error(?: (\w+))?/,
                           :ErrorCode => {
                             :match => 1,
                             :default => 'unknown'})[:ErrorCode].should == 'unknown'
        end
      end
    end


    describe 'argument parsing' do
      describe 'with no regex or dimensions declared' do
        it 'should have no dimensions' do
          event_dimensions(fake_event).should be_empty
        end
      end

      describe 'with just dimensions declared' do
        it 'should have one dimension' do
          event_dimensions(fake_event,
                          :AppName => {:property => 'source_name'}).
                          should have(1).dimension
        end

        it 'should have two dimensions' do
          event_dimensions(fake_event,
                          :AppName => {:property => 'source_name'},
                          :Process => {:property => 'program'}).
                          should have(2).dimensions
        end
      end

      describe 'with a regex and dimensions declared' do
        it 'should have one dimension' do
          event_dimensions(fake_event, /^Error (\w+)/,
                          :ErrorCode => {:match => 1}).
                          should have(1).dimension
        end

        it 'should have two dimensions' do
          event_dimensions(fake_event, /^Error (\w+)/,
                          :AppName => {:property => 'source_name'},
                          :ErrorCode => {:match => 1}).
                          should have(2).dimensions
        end
      end
    end
  end
end
