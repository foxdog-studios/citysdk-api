# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_period_select(selected = nil)
        options = [
          ['hourly' , 'Hourly' ],
          ['daily'  , 'Daily'  ],
          ['weekly' , 'Weekly' ],
          ['monthly', 'Monthly'],
          ['never'  , 'Never'  ]
        ]
        CitySDK.render_select('min_period', options, selected)
      end # def
    end # end
  end # end
end # module

