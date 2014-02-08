# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/keys' do |layer_name|
      layer = Layer.where(name: layer_name).first
      return '{}' if layer.nil?

      sql = "select keys_for_layer(#{ layer.id })"
      keys = Sequel::Model.db.fetch(sql).all

      api = CitySDK::API.new(@api_server)
      ml = api.get("/nodes?layer=#{ layer_name }&per_page=1")

      if ml[:status] == 'success' && ml[:results][0]
        h = ml[:results][0][:layers][layer_name.to_sym][:data]
        h.each_key { |key| keys[0][:keys_for_layer] << key.to_s }
      end # if

      keys[0][:keys_for_layer].uniq.to_json
    end # do
  end # class
end # module

