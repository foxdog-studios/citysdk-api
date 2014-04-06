#!/usr/bin/env ruby
# encoding: utf-8

require 'docopt'
require 'pg'

PREFIXES = [[
  'ah:',
  'ArtsHolland',
  'http://purl.org/artsholland/1.0#'
], [
  'csdk:',
  'CitySDK',
  'http://purl.org/citysdk/1.0/'
], [
  'dc:',
  'DC-Elements',
  'http://purl.org/dc/elements/1.1/'
], [
  'dct:',
  'DC-Terms',
  'http://purl.org/dc/terms/'
], [
  'foaf:',
  'FOAF',
  'http://xmlns.com/foaf/0.1/'
], [
  'gn:',
  'GeoNames',
  'http://www.geonames.org/ontology#'
], [
  'geos:',
  'GeoSparql',
  'http://www.opengis.net/ont/geosparql#'
], [
  'gr:',
  'GoodRelations',
  'http://purl.org/goodrelations/v1#'
], [
  'ical:',
  'ICAL',
  'http://www.w3.org/2002/12/cal/ical#'
], [
  'lgdo:',
  'LinkedGeoData',
  'http://linkedgeodata.org/ontology/'
], [
  'owl:',
  'OWL',
  'http://www.w3.org/2002/07/owl#'
], [
  'qudt:',
  'QUDT',
  'http://data.nasa.gov/qudt/owl/qudt#'
], [
  'rdf:',
  'RDF',
  'http://www.w3.org/1999/02/22-rdf-syntax-ns#'
], [
  'rdfs:',
  'RDF-Schema',
  'http://www.w3.org/2000/01/rdf-schema#'
], [
  'skos:',
  'SKOS',
  'http://www.w3.org/2004/02/skos/core#'
], [
  'time:',
  'Time',
  'http://www.w3.org/2006/time#'
], [
  'unit:',
  'Unit',
  'http://qudt.org/vocab/unit#'
], [
  'xml:',
  'XML',
  'http://www.w3.org/XML/1998/namespace'
], [
  'xsd:',
  'XSD',
  'http://www.w3.org/2001/XMLSchema#'
]].freeze()

def main(argv = ARGV)
  args = parse_argv(argv)
  connection_string = args.fetch('CONNECTION_STRING')
  conn = PG::Connection.connect(connection_string)
  owner_id = find_owner_id(conn, args.fetch('OWNER_EMAIL'))
  ensure_prefixes(conn, owner_id)
  0
ensure
  unless conn.nil?
    begin
      conn.close()
    rescue Exception => e
      puts e
    end # rescue
  end # unless
end # def

def parse_argv(argv)
  docopt = margin <<-'DOCOPT'
   |Create turtle prefixes.
   |
   |Usage:
   |  create_turtle_prefixes.rb CONNECTION_STRING OWNER_EMAIL
  DOCOPT
  Docopt.docopt(docopt, argv: argv)
end # def

def find_owner_id(conn, owner_email)
  sql = 'SELECT id FROM users WHERE email = $1::text;'
  result = conn.exec_params(sql, [owner_email])
  result[0].fetch('id')
ensure
  result.clear() unless result.nil?
end # def

def ensure_prefixes(conn, owner_id)
  PREFIXES.each do |values|
    prefix = values.fetch(0)
    puts "Ensuring #{ prefix }"
    unless prefix_exists?(conn, prefix)
      name = values.fetch(1)
      url = values.fetch(2)
      insert_prefix(conn, prefix, name, url, owner_id)
    end # unless
  end # do
end # def

def prefix_exists?(conn, prefix)
  print '    Looking for prefix: '
  sql = 'SELECT EXISTS(SELECT 1 FROM ldprefix WHERE prefix = $1::text);'
  result = conn.exec_params(sql, [prefix])
  found = result[0].fetch('exists') == 't'
  puts (found ? 'found' : 'not found')
  found
ensure
  result.clear() unless result.nil?
end # def

def insert_prefix(conn, prefix, name, url, owner_id)
  print '    Inserting: '
  sql = margin <<-SQL
   |INSERT
   |  INTO ldprefix (
   |    prefix,
   |    name,
   |    url,
   |    owner_id
   |  )
   |  VALUES (
   |    $1::text,   -- prefix
   |    $2::text,   -- name
   |    $3::text,   -- url
   |    $4::integer -- owner_id
   |  )
   |;
  SQL
  result = conn.exec_params(sql, [prefix, name, url, owner_id])
  puts 'done'
  return # nothing
ensure
  result.clear() unless result.nil?
end # def

def margin(string)
  string.gsub(/^\s+\|/, '')
end # def

if __FILE__ == $0
  exit main()
end # if

