class CitySDKAPI < Sinatra::Application
  delete '/:cdk_id/:layer' do |cdk_id, layer|
    login_required
    layer = Layer.where(name: layer, owner_id: current_user.id).first
    if layer.nil?
      halt 422, { error: "Invalid layer spec: #{layer}" }.to_json
    end # if
    layer_id = layer.id
    node = Node.where(cdk_id: cdk_id).first
    if(node)
      NodeData.where(:layer_id=>layer_id, :node_id => node.id).delete
      if node.layer_id == layer_id && params['delete_node'] == 'true'
        if NodeData.select(:node_id).where(:node_id => node.id).all.length > 0
          node.update(:layer_id => -1)
        else
          node.delete
        end
      end
      return 200, {
        :status => 'success'
      }.to_json
    end
    CitySDKAPI.do_abort(422,"Node '#{cdk_id}' not found." )
  end # do
end # class

