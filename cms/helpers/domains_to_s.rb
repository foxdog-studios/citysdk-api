# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def domains_to_s(domains)
        domains.join(', ')
      end # def
    end # do
  end # class
end # module

