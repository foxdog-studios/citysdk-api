# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    private

    def get_layers
      @layerSelect = Layer.selectTag()
      @selected = params[:category] || 'administrative'
      ds = Layer
      if @selected != 'all'
        ds = ds.where(Sequel.like(:category, "#{ @selected }%"))
      end # if
      @layers = ds.order(:name).all
    end # def
  end # class
end # module

