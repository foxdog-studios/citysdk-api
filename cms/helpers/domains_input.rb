# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def domains_input(user)
        value = user.domains.join(', ')
        parts = [
          '<input type="text" id="domains" name="domains" class="layer"',
          %( value="#{ value }")
        ]
        parts << ' disabled' unless current_user.admin?
        parts << '>'
        parts.join('')
      end # def
    end # do
  end # class
end # module

