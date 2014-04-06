# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/routes/?' do
    path_cdk_nodes(NODE_TYPE_ROUTE)
  end # do
end # class

