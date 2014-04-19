# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:name/data' do |name|
      login_required

      layer = Layer.where(name: name).first
      unless layer && current_user.retrieve_layer?(layer)
        halt 401, 'Not authorized'
      end # unless

      haml :layer_data, locals: {
        layer: layer,
        import: layer.import ? layer.import : Import.new
      }
    end # do
  end # class
end # module

