#encoding: utf-8

module CitySDK
  class PodNodeSerializer
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

      @node_datum_serializer = PodNodeDatumSerializer.new(options)
      @with_geometry = options.fetch(:with_geometry, false)
    end # def

    def serialize(node)
      pod = {} # Plain old data

      # The field order below should match the order returned by Waag's API.
      # Probably, fields be output in the order because most Hash
      # implementations retain order, however, it's not guaranteed.
      serialize_cdk_id(node, pod)
      serialize_name(node, pod)
      serialize_node_type(node, pod)
      serialize_geometry(node, pod)
      serialize_layer_data(node, pod)
      serialize_layer(node, pod)
      serialize_modalities(node, pod)

      pod
    end

    private

    def serialize_cdk_id(node, pod)
      pod[:cdk_id] = node.fetch(:cdk_id)
      return # nothing
    end # def

    def serialize_geometry(node, pod)
      return unless @with_geometry
      member_geometries = node[:member_geometries]
      geometry = node[:geom]
      unless member_geometries.nil? || node[:node_type] == NODE_TYPE_PTLINE
        geometry = member_geometries
      end # unless
      return if geometry.nil?
      feature = @factory.parse_wkb(geometry)
      pod[:geom] = RGeo::GeoJSON.encode(feature)
      return # nothing
    end # def

    def serialize_layer(node, pod)
      layer_id = node.fetch(:layer_id)
      layer_name = Layer.where(id: layer_id).first().name
      pod[:layer] = layer_name
      return # nothing
    end # def

    def serialize_layer_data(node, pod)
      data = node.fetch(:node_data, [])
      data_pod = {}
      data.each { |datum| serialize_layer_datum(datum, data_pod) }
      pod[:layers] = data_pod unless data_pod.empty?
      return # nothing
    end # def

    def serialize_layer_datum(datum, pod)
      datum_pod = @node_datum_serializer.serialize(datum)
      pod.merge!(datum_pod)
      return # nothing
    end # def

    def serialize_modalities(node, pod)
      modality_ids = node.fetch(:modalities)
      modality_names = CitySDK::find_modality_names(modality_ids)
      pod[:modalities] = modality_names unless modality_names.empty?
      return # nothing
    end # def

    def serialize_name(node, pod)
      name = node[:name]
      name = '' if name.nil?
      pod[:name] = name
      return # nothing
    end # def

    def serialize_node_type(node, pod)
      node_type = node.fetch(:node_type)
      node_type = PodNodeTypeSerializer.serialize(node_type)
      pod[:node_type] = node_type
      return # nothing
    end # def
  end # class
end # module

