class CitySDKAPI < Sinatra::Application
  get '/layers/:name/' do |name|
    layer = CitySDK::Layer[name: name]
    if layer.nil?
      halt 404, { error: "No layer named #{ name.inspect } exists." }.to_json
    end # if

    serializer = CitySDK::Serializer.create_serializer(params[:request_format])

    serializer.add_layer(params, request)
    serializer.serialize(params, request)
  end # end
end # class

