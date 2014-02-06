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

    Node.serializeStart(params, request)
    if params[:p]
      Node.processPredicate(results.first, params)
    else
      results.map { |item| Node.serialize(item, params) }
    end
    Node.serializeEnd(params, request)
  end # do
end # class

