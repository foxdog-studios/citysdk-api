# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/' do
    serializer = CitySDK::Serializer.create(params)
    serializer.serialize_endpoint(request.url)
  end # do
end # class

