# encoding: utf-8

# Acronyms
#
#   po  - predicate-object list element
#   pos - predicate-object list

module CitySDK
  class TurtleNodeSerializer
    def initialize(options)
      @factory = RGeo::Geographic.simple_mercator_factory(
        wkb_generator: {
          emit_ewkb_srid: true,
          hex_format: true
        },
        wkb_parser: {
          support_ewkb: true
        }
      )
      @generator = RGeo::WKRep::WKTGenerator.new()
      @node_datum_serializer = TurtleNodeDatumSerializer.new(options)
      @with_geometry = options.fetch(:with_geometry, false)
    end # def

    def serialize(node)
      subject = make_subject(node)

      pos = []
      append_title_po(pos, node)
      append_type_po(pos, node)
      append_created_on_layer_po(pos, node)
      append_modality_pos(pos, node)
      append_geometry_po(pos, node)
      append_data_pos(pos, node)
      pos = pos.join(" ;\n")

      "#{ subject }\n#{ pos } ."
    end # def

    private

    def append_created_on_layer_po(pos, node)
      layer_id = node.fetch(:layer_id)
      layer_name = Layer
          .select(:name)
          .where(id: layer_id)
          .first()
          .name
      object = "<layer/#{ layer_name }>"
      append_po(pos, ':createdOnLayer', object)
      return # nothing
    end # def

    def append_data_pos(pos, node)
      node_data = node[:node_data]
      return if node_data.nil? || node_data.empty?
      node_data.each do |node_datum|
        pos << @node_datum_serializer.serialize(node_datum)
      end # do
      return # nothing
    end # def

    def append_geometry_po(pos, node)
      return unless @with_geometry
      geometry = node[:geom]
      member_geometries = node[:member_geometries]
      node_type = node.fetch(:node_type)
      unless member_geometries.nil? || node_type == NODE_TYPE_PTLINE
        geometry =  member_geometries
      end # unless
      return if geometry.nil?
      geometry = parse_geometry(geometry)
      geometry = %{"#{ geometry }"}
      append_po(pos, 'geos:hasGeometry', geometry)
      return # nothing
    end # def

    def append_modality_pos(pos, node)
      modalities = node[:modalities]
      return if modalities.nil? || modalities.empty?
      modalities = Modality
          .select(:name)
          .where(id: modalities)
          .order(:name)
      modalities.each do |modality|
        modality = ":transportModality_#{ modality.name }"
        append_po(pos, ':hasTransportmodality', modality)
      end # do
      return # nothing
    end # def

    def append_po(pos, predicate, object)
      po = "  #{ predicate } #{ object }"
      pos << po
      return # nothing
    end # def

    def append_title_po(pos, node)
      name = node[:name]
      return if name.nil? || name.empty?
      name = escape(name)
      name = %{"#{ name }"}
      append_po(pos, 'dc:title', name)
    end # def

    def append_type_po(pos, node)
      type = node.fetch(:node_type)
      type = PodNodeTypeSerializer.serialize(type)
      type = type.capitalize()
      type = ":#{ type }"
      append_po(pos, 'a', type)
    end # def

    def escape(text)
      text.gsub('"', '\"')
    end # def

    def make_subject(node)
      "<#{ node.fetch(:cdk_id) }>"
    end # def

    def parse_geometry(geometry)
      feature = @factory.parse_wkb(geometry)
      @generator.generate(feature)
    end # def
  end # class
end # module

