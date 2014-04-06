# encoding: utf-8

module CitySDK
  class PodLayerSerializer
    def initialize(options)
      @with_bounds = options.fetch(:with_bounds, false)
    end # def

    def serialize(layer)
      pod = {
        name:         layer.name,
        category:     layer.category,
        organization: layer.organization,
        owner:        layer.owner.email,
        description:  layer.description,
        imported_at:  layer.imported_at
      }

      pod[:data_sources] = serialize_data_sources(layer.data_sources)

      layer_properties = serialize_layer_properties(layer.id)
      pod[:fields] = layer_properties unless layer_properties.empty?

      sample_url = layer.sample_url
      pod[:sample_url] = sample_url unless sample_url.nil?

      realtime = layer.realtime
      if realtime
        pod[:update_rate] = layer.update_rate
      end # if

      bounds = layer.bbox
      if @with_bounds && !bounds.nil?
        pod[:geom] = serialize_bounds(bounds)
      end # if

      pod
    end # def

    private

    def serialize_bounds(bounds)
      feature = CitySDKAPI.rgeo_factory.parse_wkb(bounds)
      RGeo::GeoJSON.encode(feature)
    end # def

    def serialize_data_source(data_source)
      equals = data_source.index('=')
      data_source = data_source[equals + 1..-1] unless equals.nil?
      data_source
    end # def

    def serialize_data_sources(data_sources)
      data_sources = [] if data_sources.nil?
      data_sources.map { |data_source| serialize_data_source(data_source) }
    end # def

    def serialize_layer_property(layer_property)
      key = layer_property.key
      type = layer_property.type
      pod = { key: key, type: type }

      unit = layer_property.unit
      if type =~ /(integer|float|double)/ && !unit.empty?
        pod[:valueUnit] = unit
      end # if

      lang = layer_property.lang
      if !lang.empty? && type == 'xsd:string'
        pod[:valueLanguange] = lang
      end # if

      eqprop = layer_property.eqprop
      unless eqprop.nil? || eqprop.empty?
        pod[:equivalentProperty] = eqprop
      end # unless

      description = layer_property.descr
      pod[:description] = description unless description.empty?

      pod
    end # def

    def serialize_layer_properties(layer_id)
      result = LayerProperty.where(layer_id: layer_id)
      result.map { |layer_property| serialize_layer_property(layer_property) }
    end # def
  end # class
end # module

