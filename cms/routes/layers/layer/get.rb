# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/' do |layer_name|
      login_required
      layer = Layer.where(name: layer_name).first
      if layer.nil? || !current_user.update_layer?(layer)
        halt 401, 'Not authorized'
      end # if
      haml :edit_layer, locals: { layer: layer }
    end # do
  end # class
end # module

