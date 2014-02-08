# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def layer_category_select()
        all = 'all'
        names = [ all ] + Category.select(:name).map { |c| c.name }
        names.sort
        html = "<select class='catprefix' onchange='layerSelect(this)'>"
        selected = params.fetch('category', all)
        names.each do |name|
          html += '<option'
          html += ' selected' if selected == name
          html += ">#{ name }</option>"
        end # do
        html += '</select>'
      end # def
    end # do
  end # class
end # module

