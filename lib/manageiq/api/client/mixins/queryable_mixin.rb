module QueryableMixin
  include QueryRelation::Queryable

  # find(#)      returns the object
  # find([#])    returns an array of the object
  # find(#, #, ...) or find([#, #, ...])   returns an array of the objects
  def find(*args)
    request_array = args.size == 1 && args[0].kind_of?(Array)
    args = args.flatten
    case args.size
    when 0
      raise "Couldn't find resource without an 'id'"
    when 1
      res = limit(1).where(resource_identifier => args[0]).to_a
      raise "Couldn't find resource with '#{resource_identifier}' #{args}" if res.blank?
      request_array ? res : res.first
    else
      raise "Multiple resource find is not supported" unless respond_to?(:query)
      query(args.collect { |id| { resource_identifier => id } })
    end
  end

  def find_by(args)
    limit(1).where(args).first
  end

  def pluck(*attrs)
    select(*attrs).to_a.pluck(*attrs)
  end

  def search(mode, options)
    options[:limit] = 1 if mode == :first
    result = get(parameters_from_query_relation(options))
    case mode
    when :first then result.first
    when :last  then result.last
    when :all   then result
    else raise "Invalid mode #{mode} specified for search"
    end
  end

  private

  def parameters_from_query_relation(query_options)
    api_params = {}
    [:offset, :limit].each { |opt| api_params[opt] = query_options[opt] if query_options[opt] }
    api_params[:attributes] = query_options[:select].join(",") if query_options[:select].present?
    if query_options[:where]
      if options.configuration["options"].include?("hide_collection")
        query_options[:where].each do |attr, value|
          if attr.to_sym == resource_identifier.to_sym
            api_params[:identifier] = value
          end
        end
      else
        api_params[:filter] ||= []
        api_params[:filter] += filters_from_query_relation("=", query_options[:where])
      end
    end
    if query_options[:not]
      api_params[:filter] ||= []
      api_params[:filter] += filters_from_query_relation("!=", query_options[:not])
    end
    if query_options[:order]
      order_parameters_from_query_relation(query_options[:order]).each { |param, value| api_params[param] = value }
    end
    api_params
  end

  def filters_from_query_relation(condition, option)
    filters = []
    option.each do |attr, values|
      Array(values).each do |value|
        value = "'#{value}'" if value.kind_of?(String) && !value.match(/^(NULL|nil)$/i)
        filters << "#{attr}#{condition}#{value}"
      end
    end
    filters
  end

  def order_parameters_from_query_relation(option)
    query_relation_option =
      if option.kind_of?(Array)
        option.each_with_object({}) { |name, hash| hash[name] = "asc" }
      else
        option.dup
      end

    res_sort_by = []
    res_sort_order = []
    query_relation_option.each do |sort_attr, sort_order|
      res_sort_by << sort_attr
      sort_order =
        case sort_order
        when /^asc/i  then "asc"
        when /^desc/i then "desc"
        else raise "Invalid sort order #{sort_order} specified for attribute #{sort_attr}"
        end
      res_sort_order << sort_order
    end
    { :sort_by => res_sort_by.join(","), :sort_order => res_sort_order.join(",") }
  end
end
