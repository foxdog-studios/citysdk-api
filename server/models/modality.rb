require 'sequel/model'

class Modality < Sequel::Model
  plugin :json_serializer

  def serialize(params)
    { id: id, name: name}
  end
end

