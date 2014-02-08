# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/new' do
      owner = current_user
      halt 403 unless owner.create_layer?
      layer = Layer.new
      layer.organization = owner.organization
      layer.data_sources = []
      layer.update_rate = 3600
      haml :new_layer, locals: { layer: layer }
    end # do
  end # class
end # module

