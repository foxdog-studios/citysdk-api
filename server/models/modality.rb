# encoding: utf-8

class Modality < Sequel::Model
  plugin :json_serializer

  def serialize(params)
    { id: id, name: name}
  end # def
end #class

