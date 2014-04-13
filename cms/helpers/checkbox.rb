# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def checkbox(name, value, checked)
        parts = [
          %(<input type="checkbox" name="#{ name }" value="#{ value }")
        ]
        parts << " checked" if checked
        parts << '>'
        parts.join('')
      end # def
    end # od
  end # class
end # module

