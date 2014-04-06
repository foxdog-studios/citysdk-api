# encoding: utf-8


class CitySDKAPI < Sinatra::Application

  ##############################################################################
  # RGeo                                                                       #
  ##############################################################################

  @@rgeo_factory = RGeo::Geographic.simple_mercator_factory(
    wkb_parser: { support_ewkb: true },
    wkb_generator: { hex_format: true, emit_ewkb_srid:  true }
  )

  @@wkb_generator = RGeo::WKRep::WKBGenerator.new(
    type_format: :ewkb,
    hex_format: true,
    emit_ewkb_srid: true
  )

  def self.rgeo_factory
    @@rgeo_factory
  end

  def self.wkb_generator
    @@wkb_generator
  end

  ##############################################################################
  # memcache utilities                                                         #
  ##############################################################################

  def self.memcache_new
    @@memcache = Dalli::Client.new('localhost:11211')
  end

  @@memcache = Dalli::Client.new('localhost:11211')

  def self.memcache_get(key)
    begin
      return @@memcache.get(key)
    rescue
      begin
        @@memcache = Dalli::Client.new('localhost:11211')
      rescue
        $stderr.puts "Failed connecting to memcache: #{e.message}\n\n"
        @@memcache = nil
      end
    end
  end

  def self.memcache_set(key, value, ttl=300)
    begin
      return @@memcache.set(key,value,ttl)
    rescue
      begin
        @@memcache = Dalli::Client.new('localhost:11211')
      rescue
        $stderr.puts "Failed connecting to memcache: #{e.message}\n\n"
        @@memcache = nil
      end
    end
  end



  ##############################################################################
  # API request utilities                                                      #
  ##############################################################################

  def self.do_abort(code, message)
    @do_cache = false
    throw(:halt, [
      code,
      {'Content-Type' => 'application/json'},
      {status: 'fail', message: message}.to_json()
    ])
  end

  def self.nodes_results(dataset, params, request)
    num_nodes = 0
    serializer = CitySDK::Serializer.create(params)
    dataset.nodes(params).each do |node|
      serializer.add_node(node)
      num_nodes += 1
    end # do

    options = self.make_serialize_options(dataset, num_nodes, params, request)
    serializer.serialize(options)
  end # def

  def self.make_serialize_options(dataset, dataset_size, params, request)
    options = dataset.get_pagination_data(params)
    if options.nil?
      options = {}
    else
      options.merge!(self.pagination_results(params, options, dataset_size))
    end
    options[:url] = request.url
    options
  end # def

  def self.pagination_results(params, pagination_data, res_length)
    if pagination_data
      if res_length < pagination_data[:page_size]
        {
          :pages => pagination_data[:current_page],
          :per_page => pagination_data[:page_size],
          :record_count => pagination_data[:page_size] * (pagination_data[:current_page] - 1) + res_length,
          :next_page => -1,
        }
      else
        {
          :pages => params.has_key?('count') ? pagination_data[:page_count] : 'not counted.',
          :per_page => pagination_data[:page_size],
          :record_count => params.has_key?('count') ? pagination_data[:pagination_record_count] : 'not counted.',
          :next_page => pagination_data[:next_page] || -1,
        }
      end
    else # pagination_data == nil
      {}
    end
  end # def
end # class

