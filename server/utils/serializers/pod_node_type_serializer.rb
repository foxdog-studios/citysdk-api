# encoding: utf-8

module CitySDK
  class PodNodeTypeSerializer
    def self.serialize(node_type)
      NODE_TYPES_TO_NAME.fetch(node_type)
    end # def
  end # class
end # module

