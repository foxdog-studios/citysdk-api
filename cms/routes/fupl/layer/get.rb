# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/fupl/:layer' do |layer|
      @layer = Layer[layer]
      erb :file_upl, :layout => false
    end # do
  end # class
end # module

