# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/data' do |layer_name|
      layer = Layer.for_name(layer_name)
      halt 404 if layer.nil?
      halt 403 unless current_user.update_layer?(layer)
      file = params.fetch('file')
      parse_uploaded_file_header(
        file.fetch(:tempfile),
        layer.name,
        CONFIG.fetch(:cms_tmp_file_dir),
        file.fetch(:filename)
      )
    end # do
  end # class
end # module

