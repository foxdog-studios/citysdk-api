#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

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

  public

  def import
    puts first_import?
  end # def

  private

  attr_reader :import_info

  def initialize(import_info)
    @import_info = import_info
  end # def

  # ========================================================================
  # = Pseudo attributes                                                    =
  # ========================================================================

  def last_imported
    import_info.last_imported
  end # def

  def layer
    import_info.layer
  end # def

  def max_frequency
    import_info.max_frequency
  end # def

  # ========================================================================

  def first_import?
    !last_imported
  end # def

  def min_period_elapsed?
    seconds_since_last_import >= max_frequency
  end # def

  def seconds_since_last_import
    Time.now - last_imported
  end # def

  def import_require?
    first_import? || min_period_elapsed?
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
end # def

def each_import_info(&block)
  LOGGER.info('Retrieving import information')
  CitySDK::Import.all.each(&block)
end # def

def margin(text)
  text.gsub(/^\s+\|/, '')
end # def

if __FILE__ == $0
  exit main()
end # if

