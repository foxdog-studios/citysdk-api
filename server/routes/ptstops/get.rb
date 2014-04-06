# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/ptstops/?' do
    path_cdk_nodes(NODE_TYPE_PTSTOP)
  end # do
end # class

