class CitySDKAPI < Sinatra::Application
  put '/nodes/:cdk_id/:layer' do |cdk_id, layer_name|
    login_required
    layer = CitySDK::Layer.where(name: layer_name,
                                 owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{name}' does not exist or you are not the " \
               "owner."
      }.to_json
    end # if

    node = Node.where(:cdk_id => cdk_id).first
    halt 422, { error: "No node with ID #{ cdk_id } exists" } if node.nil?

    json = CitySDKAPI.parse_request_json(request)['data']
    data = json['data']
    halt 422, { error: "No 'data' found in post." } if data.nil?

    node_data = NodeDatum.where(layer_id: layer_id, node_id: node.id).first
    modalities = json['modalities']
    modalities = [] if modalities.nil?
    modalities = modalities.map { |name| Modality.get_id_for_name(name) }

    if node_data.nil?
      NodeDatum.insert(
        layer_id: layer_id,
        node_id: node.id,
        data: Sequel.hstore(data),
        node_data_type: 0,
        modalities: Sequel.pg_array(modalities)
      )
    else
      unless modalities.nil?
        node_data.modalities << modalities
        node_data.modalities.flatten!.uniq!
      end # unless
      node_data.data.merge!(data)
      node_data.save
    end

    [200, { :status => 'success' }.to_json]
  end # do
end # class

