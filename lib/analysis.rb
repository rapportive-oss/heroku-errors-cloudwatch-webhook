module Analysis
  def group_by_all_dimensions(events, regex_or_dimension_declarations = nil, dimension_declarations_or_nil = nil)
    if dimension_declarations_or_nil
      regex = regex_or_dimension_declarations
      dimension_declarations = dimension_declarations_or_nil
    elsif regex_or_dimension_declarations.is_a? Regexp
      regex = regex_or_dimension_declarations
    else
      dimension_declarations = regex_or_dimension_declarations
    end
    dimension_declarations ||= {}

    all_combinations(dimension_declarations.to_a).map do |dimension_declarations|
      group_by_dimensions(events, regex, dimension_declarations)
    end.inject({}, &:merge)
  end

  def group_by_dimensions(events, *args)
    events.group_by do |event|
      event_dimensions(event, *args)
    end
  end

  def event_dimensions(event, regex_or_dimension_declarations = nil, dimension_declarations_or_nil = nil)
    if dimension_declarations_or_nil
      regex = regex_or_dimension_declarations
      dimension_declarations = dimension_declarations_or_nil
    elsif regex_or_dimension_declarations.is_a? Regexp
      regex = regex_or_dimension_declarations
    else
      dimension_declarations = regex_or_dimension_declarations
    end
    dimension_declarations ||= {}

    dimensions = {}

    message = event['message']
    match = message.match(regex) if message && regex

    dimension_declarations.each do |dimension_name, dimension_opts|
      sanity_check_dimension_opts! dimension_opts

      if dimension_opts.key? :property
        dimension_value = event[dimension_opts[:property]]
      elsif match && dimension_opts.key?(:match)
        dimension_value = match[dimension_opts[:match]]
      end

      dimensions[dimension_name] = dimension_value.nil? ? dimension_opts[:default] : dimension_value
    end

    dimensions
  end

  private
  def all_combinations(array)
    (0 .. array.size).flat_map {|n| array.combination(n).to_a }
  end

  def sanity_check_dimension_opts!(opts)
    raise ArgumentError, 'cannot specify both :property and :match' if opts.key?(:property) && opts.key?(:match)
    raise ArgumentError, 'must specify one of :property or :match' unless opts.key?(:property) || opts.key?(:match)
  end
end
