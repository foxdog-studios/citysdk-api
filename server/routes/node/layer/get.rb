# encoding: utf-8

class CitySDKAPI < Sinatra::Application

  get '/:cdk_id/:layer_name' do |cdk_id, layer_name|
    node  = Node.where(cdk_id: cdk_id).first
    if node.nil?
      halt 404, { error: "No node with ID '#{ cdk_id }'." }.to_json
    end # if

    layer = Layer.where(name: layer_name).first
    if layer.nil?
      halt 404, { error: "No layer named '#{ layer_name }'."}.to_json
    end # if

    nd = NodeData.where(node_id: node.id, layer_id: layer.id).first

    case params.fetch(:request_format)
    when 'application/json'
      {
        status: 'success',
        url: request.url,
        results: [NodeData.serialize(cdk_id, [nd.values], params)]
      }.to_json
    when 'text/turtle'
      Node.serializeStart(params, request)
      t, d = NodeData.turtelize(cdk_id, [nd.values], params)
      [
        Node.prefixes.join("\n"),
        Node.layerProps(params).join("\n"),
        d.join("\n")
      ].join("\n")
    end # case
  end # get

end # class

