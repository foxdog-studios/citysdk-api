# encoding: utf-8

require 'json'

require 'sinatra'
require 'sinatra/session'
require 'sinatra/sequel'


module CitySDK
  class CMSApplication < ::Sinatra::Application
    configure :production do |app|
      PhusionPassenger.on_event(:starting_worker_process) do |forked|
        # Disconnect if we're in smart spawning mode.
        database.disconnect if forked
      end # do
    end # do

    configure do |app|
      root_path = File.dirname(__FILE__)

      # Load external configuration.
      config_path = File.join(root_path, 'config.json')
      CONFIG = open(config_path) do |config_file|
        JSON.load(config_file, nil, symbolize_names: true)
      end # do

      enable :sessions
      set :session_expire, 60 * 60 * 24
      set :session_fail, '/login'
      set :session_secret, CONFIG.fetch(:session_secret)
      set :template_engine, :haml
      set :views, File.join(root_path, 'views')
      use Rack::MethodOverride
      register Sinatra::Session

      # Establish a connection to the database.
      user     = CONFIG.fetch(:db_user)
      password = CONFIG.fetch(:db_pass)
      host     = CONFIG.fetch(:db_host)
      database = CONFIG.fetch(:db_name)
      url = "postgres://#{ user }:#{ password }@#{ host }/#{ database }"
      app.database = url

      # Load database connection extensions.
      app.database.extension(:pg_array)
      app.database.extension(:pg_range)
      app.database.extension(:pg_hstore)

      Sequel.extension(:pg_array_ops)

      # Load Sinatra Authentication
      ::DB = app.database
      require 'sinatra-authentication'
    end # end
  end # class
end # module


require_relative 'utils/init'
require_relative 'models/init'
require_relative 'helpers/init'
require_relative 'routes/init'
require_relative 'hooks/init'

