# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def render_layers_view(category = nil)
        layers =
          if category.nil?
            Layer
          else
            Layer.where(Sequel.like(:category, category + '%'))
          end # else
        layers = layers.order(:name)
        haml :layers, locals: { layers: layers }
      end # def
    end # do
  end # class
end # module

