# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/periodic' do |layer_name|
      layer = Layer.where(name: layer_name).first()
      halt 404 unless layer
      halt 401 unless current_user.update_layer?(layer)

      # Import URL
      import_url = params['import_url']
      if import_url
        import_url = import_url.strip
        layer.import_url = import_url.empty? ? nil : import_url
      end # end

      if layer.valid?()
        layer.save()
        redirect '/layers/'
      else
        haml :edit_layer, locals: { layer: layer }
      end # else
    end # do
  end # class
end # module

