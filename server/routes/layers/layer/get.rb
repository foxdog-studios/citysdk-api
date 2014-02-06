class CitySDKAPI < Sinatra::Application
  get '/layers/:name/' do |name|
    layer = Layer[name: name]
    if layer.nil?
      halt 404, { error: "No layer named #{ name.inspect } exists." }.to_json
    end # if
    Node.serializeStart(params, request)
    layer.serialize(params, request)
    Node.serializeEnd(params, request)
  end # end
end # class

