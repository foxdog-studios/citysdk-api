# encoding: utf-8

module CitySDK
  class JsonSerializer < Serializer
    def add_layer(layer, params, request)
        hash_layer(layer, params)
    end # def

    def add_node(node, params)
        hash_node(node, params)
    end

    def serialize(params, request, pagination = {})
        hash = { status: 'success', url: request.url }
        hash = hash.merge(pagination)
        hash = hash.merge(results: @noderesults)
        hash.to_json()
    end # def

    protected

    def serialize_node_datum_field(node, node_datum, field, params)
      @noderesults << { field => node_datum[:data][field.to_sym()] }
    end # def

    private

    def hash_layer(layer, params)
      data_sources =
        if layer.data_sources.nil?
          []
        else
          layer.data_sources.map do |data_source|
            indexOfEquals = data_source.index('=')
            if indexOfEquals
              data_source[indexOfEquals+1..-1]
            else
              data_source
            end # if
          end # do
        end # if

      h = {
        name: layer.name,
        category: layer.category,
        organization: layer.organization,
        owner: layer.owner.email,
        description: layer.description,
        data_sources: data_sources,
        imported_at: layer.imported_at
      }

      res = LayerProperty.where(layer_id: layer.id)
      h[:fields] = [] if res.count > 0
      res.each do |r|
        a = {
          :key => r.key,
          :type => r.type
        }
        if r.type =~ /(integer|float|double)/ && r.unit != ''
          a[:valueUnit] = r.unit
        end # if
        if r.lang != '' && r.type == 'xsd:string'
          a[:valueLanguange] = r.lang
        end # if
        if r.eqprop && r.eqprop != ''
          a[:equivalentProperty] = r.eqprop
        end # if
        unless r.descr.empty?
          a[:description] = r.descr
        end # unless
        h[:fields] << a
      end # do

      if layer.sample_url
        h[:sample_url] = layer.sample_url
      end # if

      if layer.realtime
        h[:update_rate] = layer.update_rate
      end # if

      if !layer.bbox.nil? && params.has_key?('geom')
         h[:bbox] = RGeo::GeoJSON.encode(
           CitySDKAPI.rgeo_factory.parse_wkb(layer.bbox))
      end # if
      @noderesults << h
      h
    end

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

