#!/usr/bin/env ruby
# encoding: utf-8

require 'json'

require 'docopt'
require 'pg'

DOCOPT = <<-DOCOPT
Create layers that are required by the API.

Usage:
  create_required_layers.rb SERVER_CONFIG SETUP_CONFIG

DOCOPT

def main(argv = ARGV)
  # Load external configuration
  args = Docopt.docopt(DOCOPT, argv: argv)
  server_config = load_json(args.fetch('SERVER_CONFIG'))
  setup_config = load_json(args.fetch('SETUP_CONFIG'))
  admin_email = setup_config.fetch('admin').fetch('email')

  # Connect to the database
  print 'Connecting to database ...'
  dba = lambda { |key| setup_config.fetch('database_admin').fetch(key.to_s) }
  server = lambda { |key| server_config.fetch("db_#{ key }") }

  connection_args = {
    host:     server.call(:host),
    dbname:   server.call(:name),
    user:     dba.call(:username),
    password: dba.call(:password)
  }

  PG::Connection.new(connection_args) do |conn|
    puts ' connected'
    conn.transaction { create_required_layers(conn, admin_email) }
  end # do

  puts 'All done, goodbye!'
  0
end # def

def create_required_layers(conn, admin_email)
  # Get the ID of the admin user.
  print "Finding the admin user's ID ..."
  admin_id = find_user_id(conn, admin_email)
  puts ' found'

  print 'Inserting OSM layer ...'
  insert_osm_layer(conn, admin_id)
  puts ' inserted'

  print 'Inserting GTFS layer ...'
  insert_gtfs_layer(conn, admin_id)
  puts ' inserted'

  print 'Inserting administrative layer ...'
  insert_admr_layer(conn, admin_id)
  puts ' inserted'

  print 'Resetting layer ID sequence ...'
  reset_layer_id_seq(conn)
  puts ' reset'
end # end

def find_user_id(conn, email)
  sql = 'SELECT id FROM users WHERE email = $1::text;'
  result = conn.exec_params(sql, [email])
  result[0].fetch('id')
ensure
  result.clear unless result.nil?
end # def

def insert_osm_layer(conn, owner_id)
  data_source = 'openstreetmap.org © OpenStreetMap contributors'
  insert_layer(
    conn,
    0,                      # id
    'osm',                  # name
    owner_id,               # owner_id
    'CitySDK',              # organization
    'base.geography',       # category
    'OpenStreetMap',        # title
    'Base geograpy layer.', # description
     [data_source]          # data_sources
  )
end # def

def insert_gtfs_layer(conn, owner_id)
  insert_layer(
    conn,
    1,                               # id
    'gtfs',                          # name
    owner_id,                        # owner_id
    'CitySDK',                       # organization
    'mobility.public_transport',     # category
    'Public transport',              # title
    'Public transport information.', # description
    []                               # data_sources
  )
end # def

def insert_admr_layer(conn, owner_id)
  insert_layer(
    conn,
    2,                         # id
    'admr',                    # name
     owner_id,                 # owner_id
    'CitySDK',                 # organization
    'administrative.regions',  # category
    'Administrative borders',  # title
    'Administrative borders.', # description
    []                         # data_sources
  )
end # def

def insert_layer(
  conn,
  id,
  name,
  owner_id,
  organization,
  category,
  title,
  description,
  data_sources
)
  sql = border <<-SQL
   |INSERT INTO layers (
   |  id,
   |  name,
   |  owner_id,
   |  organization,
   |  category,
   |  title,
   |  description,
   |  data_sources
   |)
   |VALUES (
   |  $1::integer, -- id
   |  $2::text,    -- name
   |  $3::integer, -- owner_id
   |  $4::text,    -- organization
   |  $5::text,    -- category
   |  $6::text,    -- title
   |  $7::text,    -- description
   |  $8::text[]   -- data_sources
   |)
   |RETURNING id
   |;
  SQL

  data_sources = data_sources.map do |data_source|
    data_source = conn.escape_string(data_source)
    %("#{ data_source }")
  end # do
  data_sources = "{#{ data_sources.join(', ') }}"

  result = conn.exec_params(sql, [
    id,
    name,
    owner_id,
    organization,
    category,
    title,
    description,
    data_sources
  ])
  result[0].fetch('id')
ensure
  result.clear unless result.nil?
end # def

def reset_layer_id_seq(conn)
  result = conn.exec('SELECT max(id) + 1 AS restart FROM layers;')
  restart = result[0].fetch('restart')
  sql = "ALTER SEQUENCE layers_id_seq RESTART WITH #{ restart };"
  conn.exec(sql)
ensure
  result.clear unless result.nil?
end # def

def border(string)
  string.gsub(/^\s+\|/, '')
end # end

def load_json(path)
  open(path) { |file| JSON.load(file) }
end # def

if __FILE__ == $0
  exit main
end

