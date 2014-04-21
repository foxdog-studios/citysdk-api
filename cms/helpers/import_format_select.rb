# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_format_select(format = nil)
        select_options = [
          ['csv' , 'CSV' ],
          ['json', 'JSON'],
          ['kml' , 'KML' ],
          ['shp' , 'SHP' ],
          ['zip' , 'Zip' ]
        ]
        CitySDK.render_select('format', select_options, selected: format)
      end # def
    end # end
  end # end
end # module

