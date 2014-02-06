# encoding: utf-8

class CitySDKAPI < Sinatra::Application

  before do
    # Deduce the request format using helper.
    params[:request_format] = request_format
  end # do

end # class

