# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/data' do |layer_name|
      login_required

      layer = Layer.for_name(layer_name)
      if layer.nil? || !current_user.retrieve_layer?(layer)
        halt 401, 'Not authorized'
      end # if

      haml :layer_data, locals: { layer: layer }
    end # do
  end # class
end # module

