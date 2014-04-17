#!/usr/bin/env ruby

require 'docopt'
require 'json'
require 'logger'
require 'net/http'
require 'pg'
require 'sequel'

LOGGER = Logger.new(STDERR)
LOGGER.level = Logger::DEBUG

class LayerImportHandler
  def initialize(layer)
    @layer = layer
  end # def

  def handle
    LOGGER.info("Handling import for layer #{@layer.name.inspect}")
    import if import_require?
  end # def

  private

  def http
    @http ||= make_http
  end # def

  def import
    LOGGER.info('Importing data')
  end # def

  def import_url
    @import_url ||= URI.parse(@layer.import_url)
  end # def

  # Is an import required or is the layer's data up-to-date?
  #
  # The source should be (re-)imported if;
  #   a) this is the first attempt to import the source;
  #   b) is was not possible to determine when the source was last
  #      modified; or
  #   c) the source has been modified since the last import.
  def import_require?
    !imported_at || !last_modified || imported_at < last_modified
  end # def

  def imported_at
    @layer.imported_at
  end # def

  def last_modified
    @last_modified ||= retrieve_last_modified
  end # def

  def make_http
    use_ssl = import_url.scheme == 'https'
    Net::HTTP.start(import_url.host, import_url.port, use_ssl: use_ssl)
  end # def

  def retrieve_last_modified
    response = http.head(import_url.request_uri)
    last_modified = response.fetch('Last-Modified')
    last_modified = last_modified[/.*,\s+(.*)\s+\d\d:/, 1]
    Date.parse(last_modified)
  rescue => error
    LOGGER.debug("Unable to retrieve Last-Modified: #{error.message}")
    nil
  end # rescue

  def retrieve_source
    LOGGER.info("Retrieving #{import_url}")
    http.get(import_url.request_uri).body
  end # def

  def source
    @source ||= retrieve_source
  end # def
end # class


def main(argv = ARGV)
  args = parse_args(argv)

  connect_to_database(args)
  require 'sinatra-authentication'
  require 'citysdk'

  importable_layers { |layer| LayerImportHandler.new(layer).handle }

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
  get = lambda { |key| config.fetch("db_#{ key }") }
  user = get.call(:user)
  password = get.call(:pass)
  host = get.call(:host)
  name = get.call(:name)
  Sequel.connect("postgres://#{ user }:#{ password }@#{ host }/#{ name }")
end # def

def importable_layers(&block)
  LOGGER.info('Finding importable layers')
  CitySDK::Layer.exclude(import_url: nil).each(&block)
end # def

def margin(text)
  text.gsub(/^\s+\|/, '')
end # def

if __FILE__ == $0
  exit main()
end # if

