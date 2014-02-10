# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/' do |layer_name|
      login_required
      layer = Layer.where(name: layer_name).first
      halt 404 if layer.nil?
      halt 403 unless current_user.update_layer?(layer)
      haml :edit_layer, locals: { layer: layer }
    end # do
  end # class
end # module

