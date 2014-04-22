# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/upload' do |layer_name|
      layer = Layer.where(name: layer_name).first
      halt 404 unless layer
      halt 403 unless current_user.update_layer?(layer)
      FileUploadForm.new(layer, params).handle
      haml :layer_data, locals: {
        layer: layer,
        import: layer.import ? layer.import : Import.new
      }
    end # do
  end # class
end # module

