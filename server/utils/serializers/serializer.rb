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

    def process_predicate(n, params)
      p = params[:p]
      layer, field = p.split('/')
      if Layer.where(name: layer).count() == 0
        halt 422, "Layer not found: 'layer'"
      end # if
      layer_id = Layer.idFromText(layer)
      node_datum = NodeDatum.where(node_id: n[:id], layer_id: layer_id).first()
      unless node_datum.nil?
        serialize_data_datum(node, node_datum, field, params)
      end # unless
    end # def
  end # class
end # module

