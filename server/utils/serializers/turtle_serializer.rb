# encoding: utf-8

module CitySDK
  class TurtleSerializer < Serializer
    def self.create(options)
      TurtleSerializer.new(
        TurtleEndpointSerializer.new(options),
        TurtleDirectiveSerializer.new(options),
        TurtleLayerSerializer.new(options),
        TurtleNodeSerializer.new(options)
      )
    end # def

    def initialize(
      endpoint_serializer,
      directive_serializer,
      layer_serializer,
      node_serializer
    )
      super()

      @layers = {}
      @nodes = {}

      @endpoint_serializer = endpoint_serializer
      @directive_serializer = directive_serializer
      @layer_serializer = layer_serializer
      @node_serializer = node_serializer
    end # def

    def add_layer(layer)
      @layers[layer.id] = layer
    end # def

    def add_node(node)
      @nodes[node.fetch(:id)] = node
      add_layer_for_node(node)
    end # def

    def serialize(options)
      [
        serialize_directives(),
        serialize_layers(),
        serialize_nodes()
      ].join("\n\n")
    end # def

    def serialize_endpoint(url)
      @endpoint_serializer.serialize(url)
    end # def

    private

    def add_layer_for_node(node)
      layer_id = node.fetch(:layer_id)
      layer = Layer.where(id: layer_id).first()
      add_layer(layer)
    end # def

    def serialize_directives()
      @directive_serializer.serialize()
    end # def

    def serialize_layers()
      layers = @layers.values().map do |layer|
        @layer_serializer.serialize(layer)
      end # do
      layers.join("\n\n")
    end # def

    def serialize_nodes()
      nodes = @nodes.values().map { |node| @node_serializer.serialize(node) }
      nodes.join("\n\n")
    end # def
  end # class
end # module

