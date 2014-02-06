class CitySDKAPI < Sinatra::Application
  get '/:within/regions/' do
    path_regions
  end # do
end # class

