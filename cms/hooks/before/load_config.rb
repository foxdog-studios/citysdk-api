# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    before do
      @api_server = CONFIG.fetch(:ep_api_url)
      info_url = CONFIG.fetch(:ep_info_url)
      @sample_url = "#{ info_url }/map#http://#{ @api_server }/"
    end # do
  end # class
end # module

