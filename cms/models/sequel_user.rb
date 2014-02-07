# encoding: utf-8

class SequelUser
  set_primary_key :id

  def can_create_layer
    true
  end # end

  def can_retrieve_layer(layer)
    true
  end # end

  def can_update_layer(layer)
    can_modify_layer(layer)
  end # end

  def can_delete_layer(layer)
    can_modify_layer(layer)
  end # end

  private

  def can_modify_layer(layer)
    layer.owner_id == @id || admin?
  end # def
end # end

