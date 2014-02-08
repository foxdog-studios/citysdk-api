# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/' do
      render_layers_view(params['category'])
    end # do
  end # class
end # module

