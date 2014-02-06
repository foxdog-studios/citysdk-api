require 'json'
require 'sinatra/sequel'

configure do |app|
  # Load external configuration.
  path = File.join(File.dirname(__FILE__), '..', 'config.json')
  CONFIG = open(path) do |config_file|
    JSON.load(config_file, nil, symbolize_names: true)
  end # do

  # Establish a connection to the database.
  user     = CONFIG.fetch(:db_user)
  password = CONFIG.fetch(:db_pass)
  host     = CONFIG.fetch(:db_host)
  database = CONFIG.fetch(:db_name)
  app.database = "postgres://#{ user }:#{ password }@#{ host }/#{ database }"

  # Load database connection extensions.
  app.database.extension(:pg_array)
  app.database.extension(:pg_range)
  app.database.extension(:pg_hstore)
  app.database.extension(:pg_json)

  # Load Sequel extensions. Must be done after a connection has been
  # established.
  Sequel.extension(:pg_array_ops)
  Sequel.extension(:pg_hstore_ops)
  Sequel.extension(:pg_json_ops)
  Sequel::Model.plugin(:json_serializer)
  Sequel::Model.db.extension(:pagination)

  # Load Sinatra Authentication
  DB = app.database
  require 'sinatra-authentication'
end

