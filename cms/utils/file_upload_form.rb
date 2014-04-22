# -*- encoding: utf-8 -*-

module CitySDK
  class FileUploadForm
    def initialize(layer, params)
      @layer = layer
      @params = params
    end # def

    def handle
      set_id
      set_name
      set_geometry
      insert_nodes
    end # def

    private

    attr_reader :layer
    attr_reader :params

    def builder
      @builder ||= NodeBuilder.new(dataset)
    end # def

    def dataset
      @dataset ||= Dataset.load_path(uploaded_file_path, format)
    end # def

    def format
      Dataset.format_from_path(original_file_name)
    end # def

    def insert_nodes
      CitySDK.bulk_insert_nodes(_XXX_string_node_hack, layer)
    rescue => e
      fail "Bulk insert failed #{e.message}."
    end # def

    def id_field
      fail 'unique_id is require' unless params.key?('unique_id')
      params.fetch('unique_id')
    end # def

    def latitude_field
      fail 'latitude/Y field is required' unless params.key?('y')
      params.fetch('y')
    end # def

    def longitude_field
      fail 'longitude/X field is required' unless params.key?('x')
      params.fetch('x')
    end # def

    def name_field
      fail 'name field is required' unless params.key?('name')
      params.fetch('name')
    end # def

    def nodes
      @nodes ||= builder.nodes
    end # def

    def original_file_name
      params.fetch('original_file_name')
    end # def

    def set_id
      builder.set_node_id_from_data_field!(id_field)
    end # def

    def set_geometry
      builder.set_geometry_from_lat_lon!(latitude_field, longitude_field)
    end # rescue

    def set_name
      builder.set_node_name_from_data_field!(name_field)
    end # def

    def uploaded_file_path
      params.fetch('uploaded_file_path')
    end # def

    # XXX: Hack to un-sym the names in the hash for the bulk import
    #      function.
    def _XXX_string_node_hack
      JSON.parse({
        'create' => {
          'params' => {
            'create_type' => 'create',
            'node_type' => 'ptstop'
          }
        },
        'nodes' => nodes
      }.to_json)
    end # def
  end # class
end # module

