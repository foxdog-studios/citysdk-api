# encoding: utf-8

module CitySDK
  class PodEndpointSerializer
    def initialize(options)
    end # def

    def serialize(url)
      {
        status: 'success',
        name: 'CitySDK API',
        url: url,
        name: 'CitySDK Version 1.0',
        description: 'Live testing; preliminary documentation @ ' \
                     'http://dev.citysdk.waag.org',
        health: { }
      }.to_json()
    end # def
  end # class
end # module

