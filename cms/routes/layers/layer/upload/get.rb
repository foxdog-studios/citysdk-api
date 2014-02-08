# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/upload' do |layer_name|
      layer = Layer.for_name(layer_name)
      haml :file_upload, locals: { layer: layer }
    end # do
  end # class
end # module

