# encoding: utf-8

module CitySDK
  class JsonSerializer
    def self.create(options)
      self.new(
        PodEndpointSerializer.new(options),
        PodLayerSerializer.new(options),
        PodNodeSerializer.new(options)
      )
    end # def

    def initialize(endpoint_serializer, layer_serializer, node_serializer)
      super()
      @layers = []
      @nodes = []
      @endpoint_serializer = endpoint_serializer
      @layer_serializer = layer_serializer
      @node_serializer = node_serializer
    end # def

    def add_layer(layer)
      @layers << layer
    end # def

    def add_node(node)
      @nodes << node
    end # def

    def serialize(options)
      pod = { status: 'success' }
      metadata = make_metadata(options)
      pod.merge!(metadata)
      pod[:results] = serialize_layers() + serialize_nodes()
      pod.to_json()
    end # def

    def serialize_endpoint(url)
      @endpoint_serializer.serialize(url)
    end # def

    private

    def make_metadata(options)
      keys = [
        :next_page,
        :pages,
        :per_page,
        :record_count,
        :url
      ]

      pod = {}

      keys.each do |key|
        value = options[key]
        pod[key] = value unless value.nil?
      end # do

      pod
    end # def

    def serialize_layers()
      serialize_objects(@layers, @layer_serializer)
    end # def

    def serialize_nodes()
      serialize_objects(@nodes, @node_serializer)
    end # def

    def serialize_objects(objects, serializer)
      objects.map { |object| serializer.serialize(object) }
    end # def
  end # class
end # module

