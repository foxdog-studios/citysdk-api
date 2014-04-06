# encoding: utf-8

module CitySDK
  class Serializer
    def self.create(params)
      request_format = params.fetch(:request_format)

      cls =
        case request_format
        when 'application/json' then JsonSerializer
        when 'text/turtle'      then TurtleSerializer
        else fail "Invalid request format: #{ request_format }"
        end # case

      options = {
        use_webservice: !params.key?('skip_webservice'),
        with_geometry: params.key?('geom')
      }

      cls.create(options)
    end # def
  end # class
end # module

