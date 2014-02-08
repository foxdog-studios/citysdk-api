class CitySDKAPI < Sinatra::Application
  put '/nodes/:layer' do |layer_name|
    login_required

    # Get the layer and check it's owner by the user.
    layer = CitySDK::Layer.where(name: layer_name,
                                 owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{ layer_name}' does not exist or you are " \
               "not the owner."
      }.to_json
    end # if

    # Load the request body
    json = JSON.load(request.body)

    begin
      CitySDKServerDBUtils.bulk_insert_nodes(json, layer)
    rescue ArgumentError => e
      halt 422, { error: e.message }.to_json
    end

  end # do
end # class

