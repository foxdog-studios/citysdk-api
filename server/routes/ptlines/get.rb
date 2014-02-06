class CitySDKAPI < Sinatra::Application
  get '/ptlines/' do
    path_cdk_nodes(3)
  end # do
end # class

