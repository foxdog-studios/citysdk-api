class CitySDKAPI < Sinatra::Application
  get '/ptstops/' do
    path_cdk_node(2)
  end # do
end # class

