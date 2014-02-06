class CitySDKAPI < Sinatra::Application
  get '/routes/' do
    path_cdk_nodes(1)
  end # do
end # class

