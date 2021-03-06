# -*- encoding: utf-8 -*-

class CitySDKAPI < Sinatra::Application
  before do
    # Basic authentication
    header_name = 'HTTP_AUTHORIZATION'
    return unless request.env.key?(header_name)
    header_value = request.env.fetch(header_name)
    email, password = HTTPAuth::Basic.unpack_authorization(header_value)
    user = User.authenticate(email, password)
    session[:user] = user.id unless user.nil?
  end # do
end # class

