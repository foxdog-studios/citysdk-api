# encoding: utf-8

module CitySDK
  class Serializer
    def self.create_serializer(request_format)
      case request_format
      when 'application/json' then JsonSerializer.new()
      when 'text/turtle'      then TurtleSerializer.new()
      end # case
    end # def

    def initialize()
      @layers = []
      @node_types = [
        'node',
        'ptline',
        'ptstop',
        'route'
      ]
      @noderesults = []
    end # def
  end # class
end # module

