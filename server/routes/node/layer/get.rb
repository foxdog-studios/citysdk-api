# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/:cdk_id/:layer_name' do |cdk_id, layer_name|
    node  = Node.where(cdk_id: cdk_id).first()
    if node.nil?
      halt 404, { error: "No node with ID '#{ cdk_id }'." }.to_json()
    end # if

    layer = CitySDK::Layer.where(name: layer_name).first()
    if layer.nil?
      halt 404, { error: "No layer named '#{ layer_name }'."}.to_json()
    end # if

    serializer = CitySDK::Serializer.create(params)
    node_datum = NodeDatum.where(node_id: node.id, layer_id: layer.id).first()
    serializer.add_node_datum(cdk_id, [node_datum.values], params)
    serializer.serialize()
  end # do
end # class

