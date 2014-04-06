# encoding: utf-8

module CitySDK
  class PodLayerSerializer
    def initialize(options)
      @with_geometry = options.fetch(:with_geometry, false)
    end # def

    def serialize(layer)
      pod = {}
      add_name(layer, pod)
      add_category(layer, pod)
      add_owner(layer, pod)
      add_description(layer, pod)
      add_data_sources(layer, pod)
      add_imported_at(layer, pod)
      add_geometry(layer, pod)
      add_fields(layer, pod)
      add_sample_url(layer, pod)
      add_update_rate(layer, pod)
      pod
    end # def

    private

    def add_name(layer, pod)
      pod[:name] = layer.name
    end # def

    def add_category(layer, pod)
      pod[:category] = layer.category
    end # def

    def add_owner(layer, pod)
      pod[:owner] = layer.owner.email
    end # def

    def add_description(layer, pod)
      pod[:description] = layer.description
    end # def

    def add_imported_at(layer, pod)
      pod[:imported_at] = layer.imported_at
    end # def

    def add_geometry(layer, pod)
      return unless @with_geometry
      geometry = layer.bbox
      return if geometry.nil?
      geometry = CitySDKAPI.rgeo_factory.parse_wkb(geometry)
      geometry = RGeo::GeoJSON.encode(geometry)
      pod[:geom] = geometry
    end # def

    def add_data_sources(layer, pod)
      data_sources = layer.data_sources
      data_sources = [] if data_sources.nil?
      data_sources = data_sources.map do |data_source|
        equals = data_source.index('=')
        unless equals.nil?
          data_source = data_source[equals + 1..-1]
        end # unless
        data_source
      end # do
      pod[:data_sources] = data_sources
    end # def

    def add_fields(layer, pod)
      result = LayerProperty.where(layer_id: layer.id)
      fields = result.map { |layer_property| make_field(layer_property) }
      pod[:fields] = fields unless fields.empty?
    end # def

    def make_field(layer_property)
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

    def add_sample_url(layer, pod)
      sample_url = layer.sample_url
      pod[:sample_url] = sample_url unless sample_url.nil?
    end # end

    def add_update_rate(layer, pod)
      realtime = layer.realtime
      pod[:update_rate] = layer.update_rate if realtime
    end # end
  end # class
end # module

