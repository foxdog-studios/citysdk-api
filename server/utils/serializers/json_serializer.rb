# encoding: utf-8

module CitySDK
  class JsonSerializer < Serializer
    def add_layer(layer, params, request)
      {
        status: 'success',
        url: request.url,
        results: [
          layer.make_hash(params)
        ]
      }.to_json()
    end # def

    def serialize(params, request, pagination = {})
        hash = { status: 'success', url: request.url }
        hash = json.merge(pagination)
        hash.merge(results: @noderesults)
        hash.to_json()
    end # def
  end # class
end # module

