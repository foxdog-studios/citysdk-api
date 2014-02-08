# encoding: utf-8


module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def import_period_select(selected)
        html = '<select name="period">'
        periods = %w{ never monthly weekly daily hourly }
        periods.each do |period|
          html += '<option'
          if period == selected
            html += ' selected'
          end # if
          html += ">#{ period }</option>"
        end # do
        html += '</select>'
      end # def
    end # end
  end # end
end # module

