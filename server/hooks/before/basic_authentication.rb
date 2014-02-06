# encoding: utf-8

require 'httpauth/basic'


class CitySDKAPI < Sinatra::Application

  before do
    # Basic authentication
    header_name = 'HTTP_AUTHORIZATION'
    if request.env.key?(header_name)
      header_value = request.env.fetch(header_name)
      email, password = HTTPAuth::Basic.unpack_authorization(header_value)
      user = User.authenticate(email, password)
      session[:user] = user.id unless user.nil?
    end # if
  end # do

end # class

