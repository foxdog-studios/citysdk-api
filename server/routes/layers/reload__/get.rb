class CitySDKAPI < Sinatra::Application
  get '/layers/reload__' do
    @do_cache = false
    CitySDKAPI::Layer.getLayerHashes
    { status:  'success' }.to_json
  end # do
end # class

