# encoding: utf-8

module CitySDK
  def self.get_matching_layer_ids(query_or_queries)
    case query_or_queries
    when Array  then get_matching_layer_ids_array(query_or_queries)
    when String then get_matching_layer_ids_string(query_or_queries)
    else fail "Invalid layer query: #{ query_or_queries.inspect() }"
    end # case
  end # def

  private

  def self.get_matching_layer_ids_array(queries)
    layers = queries.map { |query| get_matching_layer_ids(query) }
    layers.flatten().uniq()
  end # def

  def self.get_matching_layer_ids_string(query)
    if query.include?('*')
      get_matching_layer_ids_wildcard(query)
    else
      get_matching_layer_id_name(query)
    end # else
  end # def

  def self.get_matching_layer_id_name(name)
    layer = Layer.select(:id).where(name: name).first()
    ids = []
    ids << layer.id unless layer.nil?
    ids
  end # def

  def self.get_matching_layer_ids_wildcard(query)
    # Only a single wildcard is permitted and it must appear at the
    # end of query after a separator.
    is_valid = query.length >= 3      \
        && query.scan('*').size == 1  \
        && query[-2, 2] == '.*'

    unless is_valid
      fail "A wildcard may only appear directly after a '.'"
    end # unless

    like = Sequel.like(:name, "#{ query[-2, 2] }%")
    Layer.select(:id).where(like).map(:id)
  end # def
end # module

