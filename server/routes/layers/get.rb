# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/layers/?' do
    params['count'] = ''

    pgn = CitySDK::Layer.dataset
      .name_search(params)
      .category_search(params)
      .layer_geosearch(params)
      .do_paginate(params)

    serializer = CitySDK::Serializer.create(params)

    num_layers = 0
    pgn.each do |layer|
      serializer.add_layer(layer)
      num_layers += 1
    end # do

    serializer.serialize()
  end # do
end # class

