# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/periodic' do |layer_name|
      layer = Layer.where(name: layer_name).first()
      halt 404 if layer.nil?
      halt 401 unless current_user.update_layer?(layer)

      import_url = params['import_url']
      layer.import_url = import_url unless import_url.nil?

      if layer.valid?()
        layer.save()
        redirect '/layers/'
      else
        haml :edit_layer, locals: { layer: layer }
      end # else
    end # do
  end # class
end # module

