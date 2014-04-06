# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/nodes/?' do
    path_cdk_nodes()
  end # do
end # class

