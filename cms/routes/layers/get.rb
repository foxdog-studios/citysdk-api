# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers' do
      get_layers
      erb :layers, :layout => @nolayout ? false : true
    end # do
  end # class
end # module

