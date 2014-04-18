# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_period_select(selected = nil)
        options = ['never', 'monthly', 'weekly', 'daily', 'hourly']
        options.map! { |value| [value, value.capitalize] }
        CitySDK.render_select('period', options, selected)
      end # def
    end # end
  end # end
end # module

