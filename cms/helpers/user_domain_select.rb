# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def user_domain_select(user)
        domains = user.domains
        html = '<select name="prefix"> '
        domains.sort.each do |domain|
          html += "<option>#{domain}</option>"
        end # def
        html += "</select>"
      end # def
    end # do
  end # class
end # module

