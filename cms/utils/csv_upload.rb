# encoding: utf-8

require 'base64'

require 'citysdk'

module CitySDK

class CMSApplication < Sinatra::Application

  def parseUploadedFile(file, layer_name, tmp_file_dir, original_file_name)
    importer = CitySDK::Importer.new(file.path)

    headers = case Pathname(original_file_name).extname
    when '.csv'          then importer.get_headers_from_csv()
    when '.geo', '.json' then importer.get_headers_from_json()
    when '.kml'          then importer.get_headers_from_kml()
    when '.shp'          then importer.get_headers_from_shp()
    else fail "Unknown extension for #{original_file_name}"
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

    filename = File.join(tmp_file_dir, File.basename(file.path))
    File.open(filename, 'w') do |tmp_file|
      tmp_file.write(file.read())
    end

    @erb_uploaded_file_path
    erb :selectheaders, layout: false, locals: {
      layer_name: layer_name,
      original_file_name: original_file_name,
      uploaded_file_path: filename
    }
  end # def
end # class

end # module
