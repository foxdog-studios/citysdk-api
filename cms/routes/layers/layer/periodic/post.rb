# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/periodic' do |layer_name|
      layer = Layer.where(name: layer_name).first()
      halt 404 unless layer
      halt 401 unless current_user.update_layer?(layer)

      PeriodicImportForm.update(layer, params)

      if layer.valid?()
        layer.save()
        redirect '/layers/'
      else
        haml :edit_layer, locals: { layer: layer }
      end # else
    end # do
  end # class

  private

  class PeriodicImportForm
    def self.update(layer, params)
      self.new(layer, params)
      layer
    end # def

    private

    def initialize(layer, params)
      @layer = layer
      @params = params
      update
    end # def

    def update
      update_import_format
      update_import_url
    end # def

    def update_import_format
      update_if('import_format') { |format| @layer.import_format = format }
    end # def

    def update_import_url
      update_if('import_url') { |url| @layer.import_url = url }
    end # end

    def update_import_period
      update_if('import_period') { |period| @layer.import_period = period }
    end # def

    def update_if(name, &block)
      text = @params[name]
      block.call(clean(text)) if text
    end # def

    def clean(text)
      stripped = text.strip
      stripped.empty? ? nil : stripped
    end # def
  end # class
end # module

