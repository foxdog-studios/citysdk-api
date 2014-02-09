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

      layer = Layer.for_name(layer_name)
      importer = CitySDK::Importer.new(file.path)

      headers =
        case Pathname(original_file_name).extname
        when '.csv'          then importer.get_headers_from_csv
        when '.geo', '.json' then importer.get_headers_from_json
        when '.kml'          then importer.get_headers_from_kml
        when '.shp'          then importer.get_headers_from_shp
        else fail "Unknown extension for #{ original_file_name }"
        end

      @unique_id = "<select name='unique_id'><option>&lt;no unique id&gt;</option> "
      @name = "<select name='name'><option>&lt;no name&gt;</option> "

      @house_nr = "<select name='housenumber'><option>&lt;no housenr.&gt;</option> "
      @postcode = "<select name='postcode'><option>&lt;no postcode&gt;</option> "

      headers.each do |h|
        @postcode += "<option>#{h}</option>"
        @house_nr += "<option>#{h}</option>"
        @unique_id += "<option>#{h}</option>"
        @name += "<option>#{h}</option>"
      end

      @name += "</select>"
      @unique_id += "</select>"

      @sel_x = "<select name='x'><option>&lt;no longtitude&gt;</option> "
      @sel_y = "<select name='y'><option>&lt;no latitude&gt;</option> "

      headers.each do |h|
        @sel_x += "<option value='#{h}' >#{h}</option>"
        @sel_y += "<option value='#{h}' >#{h}</option>"
      end

      @sel_x += "</select>"
      @sel_y += "</select>"

      haml :select_headers, layout: true, locals: {
        layer: layer,
        original_file_name: original_file_name,
        uploaded_file_path: upload_path
      }
    end # def
  end # class
end # module

