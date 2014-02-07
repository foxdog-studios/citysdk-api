# encoding: utf-8

module CitySDK
  class Node < Sequel::Model
    one_to_many :node_data
  end # class
end # module

