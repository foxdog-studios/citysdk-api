# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/get_layer_keys/:layer' do |layer_name|
      # TODO: Sort out tags to work directly with database. Return nothing for
      # now.

      return {}.to_json
    end # do
  end # class
end # module

