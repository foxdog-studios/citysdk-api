class CitySDKAPI < Sinatra::Application
  get '/:within/ptlines/' do
    path_cdk_nodes(3)
  end # do
end # class

