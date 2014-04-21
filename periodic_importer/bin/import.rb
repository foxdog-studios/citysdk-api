#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

require 'citysdk/client'
require 'docopt'
require 'json'
require 'logger'
require 'net/http'
require 'pg'
require 'sequel'

LOGGER = Logger.new(STDERR)
LOGGER.level = Logger::DEBUG

class Importer
  def self.import(import_info)
    self.new(import_info).import
    nil
  end # def

  private

  def initialize(import_info)
    @called_get_body_if_modified = false
    @import_info = import_info
    @factory = CitySDK::DatasetFactory.new
  end # def

  public

  def import
    return unless modified?
    # XXX: This to/from JSON is a massive hack because bulk_insert_nodes
    #      needs nuking.
    data = {
      'create' => {
        'params' => {
          'create_type' => 'create',
          'node_type' => 'node'
        }
      },
      'nodes' => build_nodes
    }.to_json
    CitySDK.bulk_insert_nodes(JSON.parse(data), layer)
  end # def

  private

  attr_reader :import_info

  def last_imported
    import_info.last_imported
  end # def

  def body
    unless @called_get_body_if_modified
      @called_get_body_if_modified = true
      @body = get_body_if_modified
    end # unless
    @body
  end # def

  def modified?
    !body.nil?
  end # def

  def build_nodes
    dataset = @factory.load_stream(format, body)
    @builder = CitySDK::NodeBuilder.new(dataset)
    set_geometry
    set_id
    set_name
    nodes = @builder.nodes
    @builder = nil
    nodes
  end # def

  def set_geometry
    return unless latitude_field && longitude_field
    @builder.set_geometry_from_lat_lon!(latitude_field, longitude_field)
  end # def

  def set_id
    return unless id_text
    if import_info.id_type == 'field'
      @builder.set_node_id_from_data_field!(id_text)
    else
      @builder.set_node_id_from_value!(id_text)
    end # else
  end # def

  def set_name
    return unless name_text
    if import_info.name_type == 'field'
      @builder.set_node_name_from_data_field!(name_text)
    else
      @builder.set_node_name_from_value!(name_text)
      @builder.set_node_data_from_key_value!('name', name_text)
    end # else
  end # def

  def id_text
    import_info.id_text
  end # def

  def name_text
    import_info.name_text
  end # def

  def latitude_field
    import_info.latitude_field
  end # def

  def longitude_field
    import_info.longitude_field
  end # def

  def format
    import_info.format
  end # def

  def layer
    import_info.layer
  end # def

  def max_frequency
    import_info.max_frequency
  end # def

  def uri
    @uri ||= URI(import_info.url)
  end # def

  def first_import?
    !last_imported
  end # def

  def import_require?
    first_import? || min_period_elapsed? || modified_body
  end # def

  def min_period_elapsed?
    seconds_since_last_import >= max_frequency
  end # def

  def seconds_since_last_import
    Time.now - last_imported
  end # def

  def get_body_if_modified
    req = Net::HTTP::Get.new(uri.request_uri)
    if last_imported
      req['If-Modified-Since'] = last_imported.to_datetime.rfc2822
    end # if
    use_ssl = uri.scheme == 'https'
    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
        http.request(req)
    end # do
    res.is_a?(Net::HTTPSuccess) ? res.body : nil
  end # def
end # class

def main(argv = ARGV)
  args = parse_args(argv)
  connect_to_database(args)
  require 'sinatra-authentication'
  require 'citysdk'
  each_import_info { |import_info| Importer.import(import_info) }
  0
end # def

def parse_args(argv)
  docopt = margin <<-'DOCOPT'
   |Automatically import data into a CitySDK instance.
   |
   |Usage:
   |  import.rb CONFIG
  DOCOPT

  Docopt.docopt(docopt, argv: argv)
end # def

def connect_to_database(args)
  LOGGER.info('Connecting to database')
  config = open(args.fetch('CONFIG')) { |config_file| JSON.load(config_file) }
  get = -> (key) { config.fetch("db_#{key}") }
  user = get.call(:user)
  password = get.call(:pass)
  host = get.call(:host)
  name = get.call(:name)
  Sequel.connect("postgres://#{user}:#{password}@#{host}/#{name}")
  Sequel.extension(:pg_array)
  Sequel.extension(:pg_hstore)
end # def

def each_import_info(&block)
  LOGGER.info('Retrieving import information')
  CitySDK::Import.exclude(max_frequency: nil).each(&block)
end # def

def margin(text)
  text.gsub(/^\s+\|/, '')
end # def

if __FILE__ == $0
  exit main()
end # if

