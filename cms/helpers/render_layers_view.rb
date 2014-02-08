# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def render_layers_view(category = nil)
        layers =
          if category.nil?
            Layer
          else
            Layer.get_layers_in_category(category)
          end # end
        haml :layers, locals: { layers: layers }
      end # def
    end # do
  end # class
end # module

