class CitySDKAPI < Sinatra::Application
  get '/ptstops/' do
    path_cdk_nodes(2)
  end # do
end # class

