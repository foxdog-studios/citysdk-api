# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_frequency_select(max_frequency = nil)
        never = 'never'
        hour = 60 * 60
        day = hour * 24
        week = day * 7
        four_weekly = week * 4
        select_options = [
          [never      , 'Never'   ],
          [hour       , 'Hourly'  ],
          [day        , 'Daily'   ],
          [week       , 'Weekly'  ],
          [four_weekly, '4-weekly']
        ]
        CitySDK.render_select(
          'max_frequency',
          select_options,
          selected: max_frequency ? max_frequency : never
        )
      end # def
    end # end
  end # end
end # module

