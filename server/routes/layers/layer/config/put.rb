class CitySDKAPI < Sinatra::Application
  put '/layers/:layer/config' do |name|
    login_required
    layer = Layer.where(name: name, owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{name}' does not exist or you are not the " \
               "owner."
      }.to_json
    end # if
    data = CitySDKAPI.parse_request_json(request)['data']
    halt 422, {error: 'Data missing'}.to_json if data.nil?
    layer.import_config = 'data'
    layer.save
    [200, { :status => 'success' }.to_json]
  end # do
end # class

