class SequelUser
  set_primary_key :id
  one_to_many :layers, key: :owner_id
end # class

