# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/upload' do |layer_id|
      haml :file_upload, locals: { layer: Layer[layer_id] }
    end # do
  end # class
end # module

