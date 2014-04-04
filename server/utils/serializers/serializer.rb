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

    def serialize_node_datum(cdk_id, h, params)
      newh = {}
      h.each do |nd|
        layer_id = nd[:layer_id]
        name = Layer.nameFromId(layer_id)

        nd.delete(:validity)
        nd.delete(:tags) if nd[:tags].nil?

        if nd[:modalities]
          nd[:modalities] = nd[:modalities].map { |m| Modality.name_for_id(m) }
        else
          nd.delete(:modalities)
        end

        nd.delete(:id)
        nd.delete(:node_id)
        nd.delete(:parent_id)
        nd.delete(:layer_id)
        nd.delete(:created_at)
        nd.delete(:updated_at)
        nd.delete(:node_data_type)
        nd.delete(:created_at)
        nd.delete(:updated_at)

        if Layer.isWebservice?(layer_id) and !params.has_key?('skip_webservice')
          nd[:data] = WebService.load(layer_id, cdk_id, nd[:data])
        end

        nd[:data] = nest(nd[:data].to_hash)
        newh[name] = nd
      end
      newh
    end # def
  end # class
end # module

