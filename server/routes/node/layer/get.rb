# encoding: utf-8

class CitySDKAPI < Sinatra::Application

  get '/:cdk_id/:layer_name' do |cdk_id, layer_name|
    node  = Node.where(cdk_id: cdk_id).first
    if node.nil?
      halt 404, { error: "No node with ID '#{ cdk_id }'." }.to_json
    end # if

    layer = CitySDK::Layer.where(name: layer_name).first
    if layer.nil?
      halt 404, { error: "No layer named '#{ layer_name }'."}.to_json
    end # if

    nd = NodeDatum.where(node_id: node.id, layer_id: layer.id).first

    serializer = CitySDK::Serializer.create_serializer(params[:request_format])

    case params.fetch(:request_format)
    when 'application/json'
      {
        status: 'success',
        url: request.url,
        results: [serializer.serialize_node_datum(cdk_id, [nd.values], params)]
      }.to_json
    when 'text/turtle'
      t, d = NodeDatum.turtelize(cdk_id, [nd.values], params)
      [
        Node.prefixes.join("\n"),
        Node.layerProps(params).join("\n"),
        d.join("\n")
      ].join("\n")
    end # case
  end # get

end # class

