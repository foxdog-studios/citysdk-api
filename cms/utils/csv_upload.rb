#encoding: utf-8

require "citysdk"
require "base64"

class CSDK_CMS < Sinatra::Base

  def parseUploadedFile(f, l, tmp_file_dir)
    begin

      pars = {
        :file_path      => f.path,
        :layername      => l,
        :email          => session[:e],
        :passw          => session[:p],
        :originalfile   => @original_file,
        :host => @apiServer
      }

      parsedUploadedFile = CitySDK::Importer.new(pars)

      @params = parsedUploadedFile.params


      @filename = File.join(tmp_file_dir, File.basename(f.path))
      @params[:file_path] = @filename + '.csdk'
      @params[:utf8_fixed] = true

      @unique_id = "<select name='unique_id'><option>&lt;no unique id&gt;</option> "
      @name = "<select name='name'><option>&lt;no name&gt;</option> "

      @house_nr = "<select name='housenumber'><option>&lt;no housenr.&gt;</option> "
      @postcode = "<select name='postcode'><option>&lt;no postcode&gt;</option> "

      nt = it = true
      @params[:fields].each do |h|

        if h == @params[:postcode]
          @postcode += "<option selected='selected'>#{h}</option>"
        else
          @postcode += "<option>#{h}</option>"
        end

        if h == @params[:housenumber]
          @house_nr += "<option selected='selected'>#{h}</option>"
        else
          @house_nr += "<option>#{h}</option>"
        end

        if h == @params[:unique_id]
          @unique_id += "<option selected='selected'>#{h}</option>"
        else
          @unique_id += "<option>#{h}</option>"
        end

        if h == @params[:name]
          @name += "<option selected='selected'>#{h}</option>"
        else
          @name += "<option>#{h}</option>"
        end
      end

      @name += "</select>"
      @unique_id += "</select>"

      if @params[:hasgeometry] == 'unknown' or @params[:hasgeometry]=='maybe'
        @sel_x = "<select name='x'><option>&lt;no longtitude&gt;</option> "
        @sel_y = "<select name='y'><option>&lt;no latitude&gt;</option> "

        @params[:fields].each do |h|
          if h == @params[:x]
            @sel_x += "<option selected value='#{h}' >#{h}</option>"
          else
            @sel_x += "<option value='#{h}' >#{h}</option>"
          end

          if h == @params[:y]
            @sel_y += "<option selected value='#{h}' >#{h}</option>"
          else
            @sel_y += "<option value='#{h}' >#{h}</option>"
          end
        end
        @sel_x += "</select>"
        @sel_y += "</select>"
      end

      @srid = @params[:srid]
      @layername = @params[:layername]
      @colsep = @params[:colsep]

      @parameters = Base64.encode64(@params.to_json)


      parsedUploadedFile.write(@filename)

      erb :selectheaders, :layout => false
    rescue Exception => e
      puts e.message
      puts e.backtrace
      raise e
    end
  end


end
