$LOAD_PATH.unshift File.dirname(__FILE__)

require 'csv'
require 'json'

require 'sinatra'

class CitySDK_API < Sinatra::Base
  attr_reader :config
  Config = JSON.parse(File.read('./config.json'),{:symbolize_names => true})
end

configure do | sinatraApp |
  set :environment, :production

  if defined?(PhusionPassenger)
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      if forked
        # We're in smart spawning mode.
        CitySDK_API.memcache_new
        Sequel::Model.db.disconnect
      end
      # Else we're in direct spawning mode. We don't need to do anything.
    end
  end

  sinatraApp.database = "postgres://#{CitySDK_API::Config[:db_user]}:#{CitySDK_API::Config[:db_pass]}@#{CitySDK_API::Config[:db_host]}/#{CitySDK_API::Config[:db_name]}"


  # sinatraApp.database.logger = Logger.new(STDOUT)

  sinatraApp.database.extension :pg_array
  sinatraApp.database.extension :pg_range
  sinatraApp.database.extension :pg_hstore
  sinatraApp.database.extension :pg_json

  require File.dirname(__FILE__) + '/api_read.rb'
  require File.dirname(__FILE__) + '/api_write.rb'
  require File.dirname(__FILE__) + '/api_delete.rb'

  Dir[File.dirname(__FILE__) + '/utils/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/utils/match/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/utils/commands/*.rb'].each {|file| require file }
  Dir[File.dirname(__FILE__) + '/models/*.rb'].each {|file| require file }

end

class CitySDK_API < Sinatra::Base

  CDK_BASE_URI = "http://rdf.citysdk.eu/"

  set :protection, :except => [:json_csrf]

  Sequel.extension :pg_hstore_ops
  Sequel.extension :pg_array_ops
  Sequel.extension :pg_json_ops

  Sequel::Model.plugin :json_serializer
  Sequel::Model.db.extension(:pagination)

  before do
    # puts "REQ = #{JSON.pretty_generate(request.env)}"
    # @do_cache = (request.env['REQUEST_METHOD'] == 'GET')
    # @cache_time = 300
    params[:request_format] = CitySDK_API.geRequestFormat(params, request)
  end

  after do
    # if @do_cache and (request.url =~ /http:\/\/.+?(\/.*$)/)
    #   @@memcache.set($1,response.body[0], @cache_time, :raw => true)
    # end
    response.headers['Content-type'] = params[:request_format] + "; charset=utf-8"
    response.headers['Access-Control-Allow-Origin'] = '*'
  end

  # keep it dry
  def path_cdk_nodes(node_type=nil)
    begin
      pgn =
        if node_type
          params["node_type"] = node_type
          Node.dataset
            .where(:node_type=>node_type)
            .geo_bounds(params)
            .name_search(params)
            .modality_search(params)
            .route_members(params)
            .nodedata(params)
            .node_layers(params)
            .do_paginate(params)
        else
          Node.dataset
            .geo_bounds(params)
            .name_search(params)
            .modality_search(params)
            .route_members(params)
            .nodedata(params)
            .node_layers(params)
            .do_paginate(params)
        end

      CitySDK_API.nodes_results(pgn, params, request)
    rescue Exception => e
      CitySDK_API.do_abort(500,"Server error (#{e.message}, \n #{e.backtrace.join('\n')}.")
    end

  end

  def path_regions
    begin
      # TODO: hard-coded layer_id of admr = 2!
      pgn = Node.dataset.where(:nodes__layer_id=>2)
        .geo_bounds(params)
        .name_search(params)
        .nodedata(params)
        .node_layers(params)
        .do_paginate(params)

      CitySDK_API.nodes_results(pgn, params, request)
    rescue Exception => e
      CitySDK_API.do_abort(500,"Server error (#{e.message}, \n #{e.backtrace.join('\n')}.")
    end
  end

  ##########################################################################################
  # URL handlers are in api_read.rb and api_write.rb
  ##########################################################################################

end
