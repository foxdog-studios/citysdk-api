# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/periodic' do |layer_name|
      layer = Layer.where(name: layer_name).first
      halt 404 unless layer
      halt 401 unless current_user.update_layer?(layer)

      import =
        if layer.import
          layer.import
        else
          Import.new(layer_id: layer.id)
        end # else

      ImportForm.update(import, params)

      if import.valid?()
        import.save()
        redirect '/layers/'
      else
        haml :edit_layer, locals: {
          layer: layer,
          import: import
        }
      end # else
    end # do
  end # class
end # module

