#!/usr/bin/env ruby

require 'json'

require 'docopt'
require 'pg'

DOCOPT = <<-DOCOPT
  Update node and node modalities using OSM route tags.

  Usage:
    update_modalities.rb CONFI_PATH

DOCOPT

def main(argv = ARGV)
  # Load configuration file
  args = Docopt.docopt(DOCOPT, argv: argv)
  config = open(args.fetch('CONFI_PATH')) do |config_file|
    JSON.load(config_file)
  end # do
  get = lambda { |key| config.fetch("db_#{ key }") }

  # Connect to the database
  print 'Connecting to database ...'
  conn = PG::Connection.new(
    host:     get.call(:host),
    dbname:   get.call(:name),
    user:     get.call(:user),
    password: get.call(:pass)
  )
  puts ' done'

  # Find route type names
  route_type_names = find_route_type_names(conn)
  puts "Found #{ route_type_names.size } route type names:"
  bullet(route_type_names)

  # Remove route type names that should be ignored
  route_type_names, ignoring = ignore_route_type_names(route_type_names)
  unless ignoring.empty?
    puts "Ignoring #{ ignoring.size } route type names:"
    bullet ignoring
  end # unless

  # Check for unmapped route type names
  unmapped = find_unmapped_route_type_names(route_type_names)
  if unmapped.empty?
    puts 'All route type names are mapped to IDs'
  else
    puts "#{ unmapped.size } route type names are not mapped to IDs:"
    bullet(unmapped)
    puts 'Please map these route type names and rerun'
    return 1
  end # else

  # Make a minimal map so that we hit the database as few times as
  # possible.
  minimal_map = make_minimal_map(route_type_names)
  minimal_map.each_pair do |name, ids|
    puts "  - #{ name.inspect } -> #{ ids.join(', ') }"
  end # end

  # Set the modalities of nodes and node data
  puts 'Setting node and node data modalities ...'
  set_node_and_node_data_modalities(conn, minimal_map)

  puts 'All done, goodbye!'
  0
ensure
  conn.finish unless conn.nil?
end # def


def find_route_type_names(conn)
  sql = border <<-SQL
   |SELECT DISTINCT data -> 'route' AS route
   |  FROM node_data
   |  WHERE
   |    data @> 'type => route'::hstore
   |    AND data -> 'route' != ''
   |  ORDER BY route
   |;
  SQL
  result = conn.exec(sql)
  result.map { |row| row.fetch('route') }
ensure
  result.clear unless result.nil?
end # def

def ignore_route_type_names(route_type_names)
  select = []
  reject = []
  route_type_names.each do |route_type_name|
    dest =
      if IGNORE_MODALITY_NAMES.include?(route_type_name)
        reject
      else
        select
      end # else
    dest << route_type_name
  end # do
  [select, reject]
end # def

def find_unmapped_route_type_names(route_type_names)
  route_type_names.reject do |route_type_name|
    MODALITY_NAMES_TO_IDS.key?(route_type_name)
  end # do
end # def

def make_minimal_map(route_type_names)
  MODALITY_NAMES_TO_IDS.select do |name, ids|
    route_type_names.include?(name)
  end
end # def

def set_node_and_node_data_modalities(conn, modality_names_to_ids)
  set_nodes_modalities = border <<-SQL
   |UPDATE nodes
   |  SET modalities = $1::integer[]
   |  FROM node_data
   |  WHERE
   |    nodes.id = node_data.node_id
   |    AND data @> $2::hstore
   |;
  SQL

  set_node_data_modalities = border <<-SQL
   |UPDATE node_data
   |  SET modalities = $1::integer[]
   |  WHERE data @> $2::hstore
   |;
  SQL

  modality_names_to_ids.each_pair do |name, ids|
    # Build there update parameters
    escaped_name = conn.escape_string(name)
    hstore = "route => #{ escaped_name }"
    ids = ids.join(', ')
    ids = "{#{ ids }}"
    params = [ids, hstore]

    # Update nodes and node data
    result = conn.exec_params(set_nodes_modalities, params)
    num_nodes = result.cmd_tuples
    result = conn.exec_params(set_node_data_modalities, params)
    num_node_data = result.cmd_tuples

    puts "  - #{ name.inspect }: #{ num_nodes } nodes, " \
         "#{ num_node_data } node data"
  end # do
end # def

def border(string)
  string.gsub(/^\s+\|/, '')
end # end

def bullet(strings)
  strings.each { |string| puts "  - #{ string.inspect }" }
end # end

MODALITY_NAMES_TO_IDS = {}

[
  [ [ 0 ]       , %w{ light_rail tram }                         ], # tram
  [ [ 1 ]       , %w{ subway }                                  ], # subway
  [ [ 2 ]       , %w{ rail railway train }                      ], # train
  [ [ 3 ]       , [ 'bus',  'night bus', 'trolleybus' ]         ], # bus
  [ [ 4 ]       , %w{ ferry }                                   ], # ferry
  [ [ 100 ]     , %w{ Running foot hiking path tracks walking } ], # foot
  [ [ 110, 111 ], %w{ bridleway foot;bicycle }                  ], # foot, bike
  [ [ 111 ]     , %w{ XXXbicycle bicycle cycling mtb }          ], # bike
  [ [ 114 ]     , %w{ road }                                    ]  # car
].each do |ids, names|
  names.each { |name| MODALITY_NAMES_TO_IDS[name] = ids }
end # do

IGNORE_MODALITY_NAMES = [ 'construction:tram' ]

if __FILE__ == $0
  exit main
end

