# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_texttype_select(name, selected = 'field')
        select_options = [
          ['field'  , 'Field'  ],
          ['literal', 'Literal']
        ]
        CitySDK.render_select('id_type', select_options, selected: selected)
      end # def
    end # do
  end # class
end # module

