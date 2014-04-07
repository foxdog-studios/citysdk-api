# encoding: utf-8

# Acronyms
#
#   po  - predicate-object list element
#   pos - predicate-object list

module CitySDK
  class TurtleNodeDatumPOSSerializer
    def initialize(options)
      @osm_property_serializer = TurtleOSMPropertySerializer.new(options)
      @use_webservice = options.fetch(:use_webservice, false)
    end # def

    def serialize(node_datum)
      ctx = make_context(node_datum)
      if osm_layer?(ctx.layer)
        make_osm_node_datum_pos(ctx)
      else
        make_non_osm_node_datum_pos(ctx)
      end # else
    end # def

    private

    def make_context(node_datum)
      TurtleNodeDatumPOSSerializerContext.new(
        find_layer(node_datum),
        find_node(node_datum),
        node_datum
      )
    end # def

    def find_layer(node_datum)
      layer_id = node_datum.fetch(:layer_id)
      Layer.where(id: layer_id).first()
    end # def

    def find_node(node_datum)
      node_id = node_datum.fetch(:node_id)
      Node.where(id: node_id).first()
    end # def

    LAYER_ID_OSM = 0

    def osm_layer?(layer)
      layer.id == LAYER_ID_OSM
    end # def


    # ======================================================================
    # = OSM node datum serializartion                                      =
    # ======================================================================

    def make_osm_node_datum_pos(ctx)
      ctx.node_datum.fetch(:data).map do |key, value|
        @osm_property_serializer.serialize(key, value)
      end # do
    end # def


    # ======================================================================
    # = Non-OSM node datum serializartion                                  =
    # ======================================================================

    def make_non_osm_node_datum_pos(ctx)
      pos = []
      add_type_po(ctx, pos)
      add_datum_pos(ctx, pos)
      pos
    end # def

    def add_type_po(ctx, pos)
      type = ctx.layer.rdf_type_uri
      return unless nonempty?(type)
      if type =~ /^http:/
        type = "<#{ type }>"
      end # if
      pos << "  a #{ type }"
    end # def

    def add_datum_pos(ctx, pos)
      extract_data(ctx).each do |key, value|
        po = make_datum_po(ctx, key, value)
        pos << po unless po.nil?
      end # do
    end # def

    def extract_data(ctx)
      data = ctx.node_datum.fetch(:data)
      webservice = ctx.layer.webservice
      if @use_webservice && nonempty?(webservice)
        data = WebService.load(ctx.layer.id, ctx.node.cdk_id, data)
      end # if
      data
    end # def

    def make_datum_po(ctx, key, value)
      layer_property = find_layer_property(ctx, key)
      return if layer_property.nil?

      # TODO: Add this to the output some how.
      make_layer_property_triple(ctx, key, value)

      layer_name = ctx.layer.name
      predicate = "<#{ layer_name }/#{ key }>"

      object = %("#{ value }")

      type = layer_property.type
      if nonempty(type) && type !~ /^xsd:string/
        object += "^^#{ type }"
      end # if

      lang = layer_property.lang
      if nonempty?(lang) && type == 'xsd:string'
        object += "@#{ lang }"
      end # if

      "  #{ predicate }#{ object }"
    end # def

    def make_layer_property_triple(ctx, key, value)
      layer_property = find_layer_property(ctx, key)

      layer_name = ctx.layer.name
      subject = "<#{ layer_name }/#{ key }>"
      pos = [
        "  :definedOnLayer <layer/#{ layer_name }>",
        '  rdfs:subPropertyOf :layerProperty'
      ]

      eqprop = layer_property.eqprop
      if nonempty?(qprop)
        pos << "  owl:equivalentProperty #{ eqprop }"
      end # unless

      description = layer_property.desc
      if nonempty?(description)
        if description =~ /\n/
          description = %(""#{ description } "")
        end # if
        pos << %(  rdfs:description "#{ description }")
      end # if

      unit = layer_property.unit
      type = layer_property.type
      if nonempty?(unit) && type =~ /xsd:(integer|float|double)/
        pos << " :hasValueUnit #{ unit }"
      end # if

      pos = pos.join(" ;\n")
      "#{ subject }\n\n#{ pos } . "
    end # def

    def find_layer_property(ctx, key)
      ctx.layer.layer_properties.each do |layer_property|
        if layer_property.key == key
          return layer_property
        end # if
      end # do
      nil
    end # def

    def nonempty?(string)
      !(string.nil? || string.empty?)
    end # def
  end # class

  class TurtleNodeDatumPOSSerializerContext
    attr_reader :layer, :node, :node_datum

    def initialize(layer, node, node_datum)
      @layer = layer
      @node = node
      @node_datum = node_datum
    end # def
  end # class
end # module

