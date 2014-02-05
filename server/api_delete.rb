class CitySDK_API < Sinatra::Base
  delete '/layers/:layer' do |layer|
    login_required
    layer = Layer.where(name: layer, owner_id: current_user.id).first
    if layer.nil?
      halt 422, { error: "Invalid layer spec: #{layer}" }.to_json
    end # if
    layer_id = layer.id

    if(layer_id > 2)
      #delete node_data
      NodeDatum.where('layer_id = ?', layer_id).delete

      #delete nodes
      nodes = Node.select(:id).where(:layer_id => layer_id)
      ndata = NodeDatum.select(:node_id).where(:node_id => nodes)
      Node.where(:layer_id => layer_id).exclude(:id => ndata).delete
      Node.where(:layer_id => layer_id).update(:layer_id => -1)

      if( params['delete_layer'] == 'true' )
        Layer.where(:id => layer_id).delete
        Layer.getLayerHashes
      else
        Layer.where(:id => layer_id).update(:import_status => 'all cleared')
      end

      return 200, {
        :status => 'success'
      }.to_json
    end
    CitySDK_API.do_abort(422,"OSM, GTFS or ADMR layers cannot be deleted..")
  end


  delete '/:cdk_id/:layer' do |cdk_id, layer|
    login_required
    layer = Layer.where(name: layer, owner_id: current_user.id).first
    if layer.nil?
      halt 422, { error: "Invalid layer spec: #{layer}" }.to_json
    end # if
    layer_id = layer.id
    node = Node.where(cdk_id: cdk_id).first
    if(node)
      NodeDatum.where(:layer_id=>layer_id, :node_id => node.id).delete
      if( (node.layer_id == layer_id) and (params['delete_node'] == 'true') )
        if NodeDatum.select(:node_id).where(:node_id => node.id).all.length > 0
          node.update(:layer_id => -1)
        else
          node.delete
        end
      end
      return 200, {
        :status => 'success'
      }.to_json
    end
    CitySDK_API.do_abort(422,"Node '#{cdk_id}' not found." )
  end

end



