# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_format_select(selected = nil)
        options = [
          ['csv' , 'CSV' ],
          ['json', 'JSON'],
          ['kml' , 'KML' ],
          ['shp' , 'SHP' ],
          ['zip' , 'Zip' ]
        ]
        CitySDK.render_select('import_format', options, selected)
      end # def
    end # end
  end # end
end # module

