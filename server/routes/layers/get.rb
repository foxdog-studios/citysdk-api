class CitySDKAPI < Sinatra::Application
  get '/layers/' do
    params['count'] = ''

    pgn = CitySDK::Layer.dataset
      .name_search(params)
      .category_search(params)
      .layer_geosearch(params)
      .do_paginate(params)

    serializer = CitySDK::Serializer.create_serializer(params[:request_format])

    res = 0
    pgn.each do |layer|
      serializer.add_layer(layer, params, request)
      res += 1
    end # do

    serializer.serialize(
      params,
      request,
      CitySDKAPI::pagination_results(
        params,
        pgn.get_pagination_data(params),
        res
      )
    )
  end # do
end # class

