class CitySDKAPI < Sinatra::Application
  get '/regions/?' do
    path_regions
  end # do
end # class

