# encoding: utf-8

require 'base64'
require 'json'
require 'pathname'
require 'uri'

require 'haml'

require 'rack-flash'

require 'sinatra'
require 'sinatra/session'
require 'sinatra/sequel'

module CitySDK
  class CMSApplication < Sinatra::Application
    register Sinatra::Session
    use Rack::Flash

    configure :production do |app|
      PhusionPassenger.on_event(:starting_worker_process) do |forked|
        # Disconnect if we're in smart spawning mode.
        database.disconnect if forked
      end # do
    end # do

    configure do |app|
      root_path = Pathname(__FILE__).dirname

      # Load external configuration.
      config_path = File.join(root_path, 'config.json')
      CONFIG = open(config_path) do |config_file|
        JSON.load(config_file, nil, symbolize_names: true)
      end # do

      # Views
      views_path = root_path.join('views')
      set :views, views_path

      # Sessions
      enable :sessions
      set :session_expire, 60 * 60 * 24
      set :session_fail, '/login'
      set :session_secret, CONFIG.fetch(:session_secret)

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

      #
      # Sinatra Authentication (SA)
      #

      # SA requires that DB be defined before you require it.
      ::DB = app.database
      require 'sinatra-authentication'

      # Use our own views
      set :sinatra_authentication_view_path, views_path.join('user')

    end # end
  end # class
end # module

require 'citysdk'
require 'citysdk/client'
require_relative 'utils/init'
require_relative 'models/init'
require_relative 'helpers/init'
require_relative 'routes/init'
require_relative 'hooks/init'

