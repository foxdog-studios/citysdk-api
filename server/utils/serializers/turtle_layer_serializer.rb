# encoding: utf-8

module CitySDK
  class TurtleLayerSerializer
    def initialize(options)
      @with_bounds = options.fetch(:with_bounds, false)
    end # def

    def serialize(layer)
      subject = "<layer/#{ layer.name }>"

      predicates = [ '  a :Layer' ]
      predicates << serialize_description(layer.description)
      predicates << serialize_owner(layer)
      data_sources = try_serialize_data_sources(layer)
      predicates << data_sources unless data_sources.nil?

      layer_properties = LayerProperty.where(layer_id: layer.id)
      layer_properties.each do |layer_property|
        predicates << serialize_layer_property(layer_property)
      end # do

      if @with_bounds
        bounds = try_serialize_bounds(layer)
        predicates << bounds unless bounds.nil?
      end # if

      [
        subject,
        "\n",
        predicates.join(" ;\n"),
        ' .'
      ].join()
    end # def

    def serialize_description(description)
      description = '' if description.nil?
      description = description.strip()
      if description =~ /\n/
        description = '""%s""' % [ description ]
      end # if
      '  rdfs:description "%s"' % [ description ]
    end # def

    def serialize_layer_property(layer_property)
      key = layer_property.key
      type = layer_property.type

      has_data_field = margin <<-TURTLE
      |  :hasDataField [
      |    rdfs:label #{ key };
      |    :valueType #{ type };
      |  ]
      TURTLE

      parts = [ has_data_field ]

      unit = layer_property.unit
      if type =~ /(integer|float|double)/ && !unit.empty?
        parts << "    :valueUnit #{ unit } ;"
      end # if

      lang = layer_property.lang
      if lang != '' && type == 'xsd:string'
        parts << '    :valueLanguange "%s" ;' % [ lang ]
      end # if

      eqprop = layer_property.eqprop
      if !eqprop.nil? && eqprop != ''
        parts << '    owl:equivalentProperty "%s" ;' % [ eqprop ]
      end # if

      description = layer_property.descr
      unless description.empty?
        parts << serialize_description(description)
      end # unless

      parts.join("\n")
    end # def

    def serialize_owner(layer)
      organization = layer.organization.strip()
      email = layer.owner.email.strip()
      created_by = margin <<-TURTLE
      |  :createdBy [
      |    foaf:name "#{ organization }" ;
      |    foaf:mbox "#{ email }"
      |  ]
      TURTLE
      created_by.rstrip()
    end # def

    def try_serialize_bounds(layer)
        bounds = layer.bbox
        return if bounds.nil?
        feature = CitySDKAPI.rgeo_factory.parse_wkb(bounds)
        wkt = RGeo::WKRep::WKTGenerator.new.generate(feature)
        '  geos:hasGeometry "%s"' % [ wkt ]
    end # def

    def try_serialize_data_sources(layer)
      data_sources = layer.data_sources
      if data_sources.nil? || data_sources.empty?
        return
      end # if
      data_sources = data_sources.map do |data_source|
        equals = data_source.index('=')
        unless equals.nil?
          data_source = data_source[equals + 1..-1]
        end # unless
        '  :dataSource "%s"' % [ data_source ]
      end # do
      data_sources.join("\n")
    end # def
  end # class
end # module

