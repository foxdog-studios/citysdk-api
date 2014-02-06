# encoding: utf-8

class CitySDKAPI < Sinatra::Application

  after do
    content_type = "#{ params.fetch(:request_format) }; charset=utf-8"
    response.headers['Content-type'] = content_type
    response.headers['Access-Control-Allow-Origin'] = '*'
  end # do

end # class

