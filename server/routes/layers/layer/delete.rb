# -*- encoding: utf-8 -*-

class CitySDKAPI < Sinatra::Application
  delete '/layers/:layer_name/' do |layer_name|
    layer = CitySDK::Layer.for_name(layer_name)

    if layer.nil?
      halt 422, { error: "No layer named #{ layer_name }." }.to_json
    end # if

    unless layer.deletable?
      halt 422, {
        error: "The #{ layer_name } layer cannot be deleted."
      }.to_json
    end # if

    database.transaction { CitySDK::delete_layer!(layer) }
    [ 204, { status: 'success' }.to_json ]
  end # do
end # class

