# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    def parse_uploaded_file_header(
      file,
      layer_name,
      tmp_file_dir,
      original_file_name
    )

      # Save the temporary file so we can recover the data once the
      # user has selected the headers.
      path = file.path
      dirname = File.dirname(path)
      basename = "saved-#{ File.basename(path) }"
      upload_path = File.join(dirname, basename)
      open(upload_path, 'w') { |save_file| save_file.write(file.read) }

      layer = Layer.where(name: layer_name).first
      importer = CitySDK::Importer.new(file.path)

      headers =
        case Pathname(original_file_name).extname
        when '.csv'          then importer.get_headers_from_csv
        when '.geo', '.json' then importer.get_headers_from_json
        else fail "Unknown extension for #{ original_file_name }"
        end

      select_options = headers.sort.map { |header| [header, header] }

      haml :select_headers, layout: true, locals: {
        layer: layer,
        id_select: CitySDK::render_select('unique_id', select_options),
        name_select: CitySDK::render_select('name', select_options),
        x_select: CitySDK::render_select('x', select_options),
        y_select: CitySDK::render_select('y', select_options),
        original_file_name: original_file_name,
        uploaded_file_path: upload_path
      }
    end # def
  end # class
end # module

