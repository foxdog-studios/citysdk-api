# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/upload' do |layer_name|
      # Remove parameters for which no column was selected.
      params.reject! do |_, value|
        value.is_a?(String) && value.start_with?('<no')
      end # do

      # Get the layer and check the user can import data into it.
      layer = Layer.for_name(layer_name)
      halt 404 if layer.nil?
      halt 403 unless current_user.update_layer?(layer)

      original_file_name = params.fetch('original_file_name')
      ext = File.extname(original_file_name).downcase
      builder = CitySDK::NodeBuilder.new
      file_name = params.fetch('uploaded_file_path')

      case ext
      when '.csv'
        builder.load_data_set_from_csv!(file_name)
      when '.json'
        builder.load_data_set_from_json!(file_name)
      when '.zip'
        builder.load_data_set_from_zip!(file_name)
      else
        halt 422, { error: "Unknown file extension: #{ ext }" }.to_json
      end

      begin
        x = params.fetch('x')
        y = params.fetch('y')
        builder.set_geometry_from_lat_lon!(x, y)
      rescue KeyError
        halt 422, { error: 'Bad key for x or y' }.to_json
      end

      builder.set_node_id_from_data_field!(params.fetch('unique_id'))
      builder.set_node_name_from_data_field!(params.fetch('name'))
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

      require 'pp'; pp json, layer

      begin
        CitySDK.bulk_insert_nodes(json, layer)
      rescue ArgumentError => e
        halt 422, { error: e.message }.to_json
      end

      haml :layer_data, locals: { layer: layer }
    end # do
  end # class
end # module

