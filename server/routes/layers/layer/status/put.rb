class CitySDKAPI < Sinatra::Application
 put '/layers/:layer/status' do |name|
    login_required
    layer = CitySDK::Layer.where(name: name, owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{name}' does not exist or you are not the " \
               "owner."
      }.to_json
    end # if
    data = CitySDKAPI.parse_request_json(request)['data']
    halt 422, { error: 'Layer status data missing' }.to_json if data.nil?
    layer.import_status = 'data'
    layer.save
    [200, { status: 'success' }.to_json]
  end # do
end # class

