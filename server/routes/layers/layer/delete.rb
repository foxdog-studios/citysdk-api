class CitySDKAPI < Sinatra::Application
  delete '/layers/:layer' do |layer|
    login_required
    layer = Layer.where(name: layer, owner_id: current_user.id).first
    if layer.nil?
      halt 422, { error: "Invalid layer spec: #{layer}" }.to_json
    end # if
    layer_id = layer.id

    if layer_id <= 2
      halt 422, { error: 'OSM, GTFS or ADMR layers cannot be deleted.' }.to_json
    end # if

    # Delete node_data
    NodeDatum.where('layer_id = ?', layer_id).delete

    # Delete nodes
    nodes = Node.select(:id).where(:layer_id => layer_id)
    ndata = NodeDatum.select(:node_id).where(:node_id => nodes)
    Node.where(:layer_id => layer_id).exclude(:id => ndata).delete
    Node.where(:layer_id => layer_id).update(:layer_id => -1)

    if params['delete_layer'] == 'true'
      Layer.where(:id => layer_id).delete
      Layer.getLayerHashes
    else
      Layer.where(:id => layer_id).update(:import_status => 'all cleared')
    end # else

    [200, { status: 'success' }.to_json]
  end
end # class

