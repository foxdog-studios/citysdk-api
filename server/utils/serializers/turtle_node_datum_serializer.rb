# encoding: utf-8

# Acronyms
#
#   po  - predicate-object list element
#   pos - predicate-object list

module CitySDK
  class TurtleNodeDatumSerializer
    def initialize(options)
      @osm_property_serializer = TurtleOSMPropertySerializer.new(options)
      @use_webservice = options.fetch(:use_webservice, false)
    end # def

    def serialize(node_datum)
      layer = find_layer(node_datum)
      node = find_node(node_datum)

      if osm_layer?(layer)
        serialize_osm_node_datum(layer, node, node_datum)
      else
        serialize_non_osm_node_datum(layer, node, node_datum)
      end # else
    end # def

    private

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

    def serialize_osm_node_datum(layer, node, node_datum)
      subject = make_subject(layer, node)
      make_osm_predicate_object_list(node_datum)
    end # def

    def make_osm_predicate_object_list(node_datum)
      data = node_datum.fetch(:data)
      pos = data.map do |key, value|
        @osm_property_serializer.serialize(key, value)
      end # do
      pos.join(" ;\n")
    end # def


    # ======================================================================
    # = Non-OSM node datum serializartion                                  =
    # ======================================================================

    def serialize_non_osm_node_datum(layer, node, node_datum)
      subject = make_subject(layer, node)
      pos = []
      append_type_po(layer, node_datum, pos)
      serialize_data(layer, node_datum)
    end # def


    # ======================================================================
    # = Generic node datum serializartion                                  =
    # ======================================================================

    def make_subject(layer, node)
      "#{ node.cdk_id }/#{ layer.name }"
    end # def


    # ======================================================================
    # = Misc.                                                              =
    # ======================================================================

    def extract_data(layer, node_datum)
      data = node_datum.fetch(:data)
      webservice = layer.webservice
      if @use_webservice && !(webservice.nil? || webservice.empty?)
        data = WebService.load(layer.id, node_datum.fetch(:cdk_id), data)
      end # if
      data
    end # def


    def append_type_po(layer, node_datum, pos)
      type = layer.rdf_type_uri
      if type.nil? || type.empty?
        return
      end # if
      if type =~ /^http:/
        type = "<#{ type }>"
      end # if
      append_po('a', type, pos)
      return # nothing
    end # def

    def append_po(predicate, object, pos)
      pos << "  #{ predicate } #{ object }"
      return # nothing
    end # def

    def serialize_data(layer, node_datum)
      data = extract_data(layer, node_datum)
      data.each { |key, value| serialize_datum(key, value) }
    end # def

    def serialize_datum(key, value)
      make_layer_property()

      if type =~ /xsd:anyURI/i
        s  = "\t #{prop} <#{v}>"
      else
        s  = "\t #{prop} \"#{v}\""
        s += "^^#{type}" if type and type !~ /^xsd:string/
        s += "#{lang}" if lang and type == 'xsd:string'
      end

      datas << s + " ;"
    end # def

    def make_layer_property(layer, key)
      layer_property = find_layer_property(layer.id, key)
      subject = "<#{ layer.name }/#{ key }>"

      pos = []
      lp  = "#{ subject }"
      lp += "\n\t :definedOnLayer <layer/#{ layer.name }> ;"
      lp += "\n\t rdfs:subPropertyOf :layerProperty ;"

      if eqpr
        lp += "\n\t owl:equivalentProperty #{ eqpr } ;"
      end # if

      if eqpr && (eqpr =~ /^([a-z]+\:)/)
        @@prefixes << $1
      end # if

      if !desc.nil? && desc =~ /\n/
        lp += "\n\t rdfs:description \"\"\"#{ desc }\"\"\" ;"
      elsif !desc.nil?
        lp += "\n\t rdfs:description \"#{ desc }\" ;"
      end # elsif

      if unit && type =~ /xsd:(integer|float|double)/
        lp += "\n\t :hasValueUnit #{ unit } ;"
      end # if

      "#{ subject }\n#{ predicate_object_list } ."
    end # def

    def find_layer_property(layer_id, key)
      model = LayerProperty
          .where(key: key, layer_id: layer_id)
          .first()
      attrs = [
        :descr,
        :eqprop,
        :lang,
        :type,
        :unit
      ]
      hash = {}
      attrs.each do |attr|
        if model.nil?
          value = nil
        else
          value = model[attr]
          value = nil if value.empty?
        end # else
        hash[attr] = value
      end # do
      hash
    end # def
  end # class
end # module

