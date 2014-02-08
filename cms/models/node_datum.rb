# encoding: utf-8

module CitySDK
  class NodeDatum < Sequel::Model
    many_to_one :node
    many_to_one :layer
  end # class
end # module

