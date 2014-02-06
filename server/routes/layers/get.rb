class CitySDKAPI < Sinatra::Application
  get '/layers/' do
    params['count'] = ''

    pgn = Layer.dataset
      .name_search(params)
      .category_search(params)
      .layer_geosearch(params)
      .do_paginate(params)

    Node.serializeStart(params, request)

    res = 0
    pgn.each do |l|
      l.serialize(params, request)
      res += 1
    end # do

    Node.serializeEnd(
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

