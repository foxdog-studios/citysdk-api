# encoding: utf-8

module CitySDK
  class JsonSerializer
    def self.create(options)
      layer_serializer = PodLayerSerializer.new(options)
      node_serializer = PodNodeSerializer.new(options)
      self.new(layer_serializer, node_serializer)
    end # def

    def initialize(layer_serializer, node_serializer)
      super()
      @layers = []
      @nodes = []
      @layer_serializer = layer_serializer
      @node_serializer = node_serializer
    end # def

    def add_layer(layer)
      @layers << layer
    end # def

    def add_node(node)
      @nodes << node
    end # def

    def serialize()
      results = serialize_layers() + serialize_nodes()
      pod = { results: results }
      pod.to_json()
    end # def

    private

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

