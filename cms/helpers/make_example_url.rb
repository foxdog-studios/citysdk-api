# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def make_example_url(layer)
        URI.join(CONFIG.fetch(:ep_api_url), layer.sample_url)
      end # def
    end # do
  end # class
end # module

