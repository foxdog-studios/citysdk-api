# encoding: utf-8

class CitySDKAPI < Sinatra::Application

  before do
    # Decude the request format using helper.
    params[:request_format] = request_format
  end # do

end # class

