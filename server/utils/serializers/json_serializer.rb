# encoding: utf-8

module CitySDK
  class JsonSerializer < Serializer
    def add_layer(layer, params, request)
      {
        status: 'success',
        url: request.url,
        results: [
          layer.make_hash(params)
        ]
      }.to_json()
    end # def

    def add_node(node, params)
        hash_node(node, params)
    end

    def serialize(params, request, pagination = {})
        hash = { status: 'success', url: request.url }
        hash = json.merge(pagination)
        hash.merge(results: @noderesults)
        hash.to_json()
    end # def

    protected

    def serialize_data_datum(node, node_datum, field, params)
      @noderesults << { field => node_datum[:data][field.to_sym()] }
    end # def

    private

    def hash_node(h, params)
      if h[:node_data]
        h[:layers] = NodeDatum.serialize(h[:cdk_id], h[:node_data], params)
      end
      # members not directly exposed,
      # call ../ptstops form members of route, f.i.
      h.delete(:members)

      h[:layer] = Layer.nameFromId(h[:layer_id])
      if h[:name].nil?
        h[:name] = ''
      end
      if params.has_key? "geom"
        if h[:member_geometries] && h[:node_type] != 3
          h[:geom] = RGeo::GeoJSON.encode(
            CitySDKAPI.rgeo_factory.parse_wkb(h[:member_geometries]))
        elsif h[:geom]
          h[:geom] = RGeo::GeoJSON.encode(
            CitySDKAPI.rgeo_factory.parse_wkb(h[:geom]))
        end
      else
        h.delete(:geom)
      end

      if h[:modalities]
        h[:modalities] = h[:modalities].map { |m| Modality.name_for_id(m) }
      else
        h.delete(:modalities)
      end

      h.delete(:related) if h[:related].nil?
      h.delete(:member_geometries)
      h[:node_type] = @node_types[h[:node_type]]
      h.delete(:layer_id)
      h.delete(:id)
      h.delete(:node_data)
      h.delete(:created_at)
      h.delete(:updated_at)

      if h.has_key? :collect_member_geometries
        h.delete(:collect_member_geometries)
      end
      @noderesults << h
      h
    end # def
  end # class
end # module

