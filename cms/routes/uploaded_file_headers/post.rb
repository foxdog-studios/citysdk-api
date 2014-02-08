# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/uploaded_file_headers' do
      params.each do |k,v|
        params.delete(k) if v =~ /^<no\s+/
      end # do

      layer_name = params[:layer_name]
      layer = Layer.where(name: layer_name, owner_id: current_user.id).first

      builder = CitySDK::NodeBuilder.new

      file_name = params[:uploaded_file_path]
      ext = File.extname(params[:original_file_name])

      case ext
      when '.csv'
        builder.load_data_set_from_csv!(file_name)
      when '.json'
        builder.load_data_set_from_json!(file_name)
        builder.set_geometry_from_lat_lon!('lat', 'lon')
      when '.zip'
        builder.load_data_set_from_zip!(file_name)
      else
        halt 422, { error: "Unknown file extension: #{ext}" }.to_json
      end

      begin
        builder.set_geometry_from_lat_lon!(params[:x], params[:y])
      rescue KeyError => e
        halt 422, { error: 'Bad key for x or y' }.to_json
      end
      builder.set_node_id_from_data_field!(params[:unique_id])
      builder.set_node_name_from_data_field!(params[:name])

      nodes = builder.build

      # XXX: Hack to un-sym the names in the hash for the bulk import
      # function.
      json = JSON.parse({
        'create' => {
          'params' => {
            'create_type' => 'create',
            'node_type' => 'ptstop'
          }
        },
        'nodes' => nodes
      }.to_json)

      begin
        CitySDKServerDBUtils.bulk_insert_nodes(json, layer)
      rescue ArgumentError => e
        halt 422, { error: e.message }.to_json
      end

      redirect "/layers/#{params[:layer_name]}/stats"
    end # do
  end # class
end # module

