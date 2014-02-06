class CitySDKAPI < Sinatra::Application
  get '/:within/nodes/' do
    path_cdk_nodes
  end # do
end # class

