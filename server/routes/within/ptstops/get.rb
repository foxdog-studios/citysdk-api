class CitySDKAPI < Sinatra::Application
  get '/:within/ptstops/' do
    path_cdk_nodes(2)
  end # do
end # class

