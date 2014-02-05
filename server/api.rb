$LOAD_PATH.unshift File.dirname(__FILE__)

require 'csv'
require 'json'

require 'httpauth/basic'
require 'sinatra'
require 'sinatra/sequel'


class CitySDK_API < Sinatra::Base
  attr_reader :config
  Config = JSON.parse(File.read('./config.json'), symbolize_names: true)
end


configure do |app|
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

  app.database = "postgres://#{CitySDK_API::Config[:db_user]}:#{CitySDK_API::Config[:db_pass]}@#{CitySDK_API::Config[:db_host]}/#{CitySDK_API::Config[:db_name]}"

  app.database.extension :pg_array
  app.database.extension :pg_range
  app.database.extension :pg_hstore
  app.database.extension :pg_json

  DB = app.database
  require 'sinatra-authentication'

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
    # Basic authentication
    header_name = 'HTTP_AUTHORIZATION'
    if request.env.key?(header_name)
      header_value = request.env.fetch(header_name)
      email, password = HTTPAuth::Basic.unpack_authorization(header_value)
      user = User.authenticate(email, password)
      session[:user] = user.id unless user.nil?
    end # if

    params[:request_format] = CitySDK_API.geRequestFormat(params, request)
  end # do

  after do
    response.headers['Content-type'] = params[:request_format] + '; charset=utf-8'
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
end

