# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    delete '/layers/:layer_name/' do |layer_name|
      layer = Layer.for_name(layer_name)
      halt 404 if layer.nil?
      halt 403 unless current_user.delete_layer?(layer)
      database.transaction { CitySDK::delete_layer!(layer) }
      redirect '/layers/'
    end # do
  end # class
end # module

