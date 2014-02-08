# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    delete '/layers/:layer_name/' do |layer_name|
      layer = Layer.get_by_name(layer_name)
      halt 404 if layer.nil?
      halt 403 unless current_user.can_delete_layer(layer)
      # TODO: Delete via DAL
      redirect '/layers/'
    end # do
  end # class
end # module

