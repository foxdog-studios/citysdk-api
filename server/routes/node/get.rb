# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  get '/:cdk_id' do |cdk_id|
    results = Node
      .where(cdk_id: cdk_id)
      .node_layers(params)
      .nodes(params)

    if results.empty?
      halt 404, { error: "No node with cdk_id '#{ cdk_id }'." }.to_json()
    end

    serializer = CitySDK::Serializer.create(params)

    if params[:p]
      # TODO: What's this? Once known, serialize it.
      serializer.process_predicate(results.first, params)
    else
      results.map { |item| serializer.add_node(item) }
    end
    serializer.serialize()
  end # do
end # class

