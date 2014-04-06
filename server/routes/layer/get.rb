# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/layer/:name/?' do |name|
    layer = CitySDK::Layer[name: name]
    if layer.nil?
      error = "No layer named #{ name.inspect } exists."
      halt 404, { error:  error }.to_json()
    end # if

    serializer = CitySDK::Serializer.create(params)
    serializer.add_layer(layer)
    serializer.serialize()
  end # do
end # class

