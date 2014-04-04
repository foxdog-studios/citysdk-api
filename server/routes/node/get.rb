# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/:cdk_id' do |cdk_id|
    results = Node
      .where(cdk_id: cdk_id)
      .node_layers(params)
      .nodes(params)

    if results.empty?
      halt 404, { error: "No node with cdk_id '#{ cdk_id }'." }.to_json
    end

    serializer = CitySDK::Serializer.create_serializer(params[:request_format])

    if params[:p]
      serializer.process_predicate(results.first, params)
    else
      results.map { |item| serializer.add_node(item, params) }
    end
    serializer.serialize(params, request)
  end # do
end # class

