# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/ptlines/?' do
    path_cdk_nodes(NODE_TYPE_PTLINE)
  end # do
end # class

