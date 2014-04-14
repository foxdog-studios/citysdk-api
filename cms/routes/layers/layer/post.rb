# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/?' do |layer_name|
      layer = Layer.for_name(layer_name)
      if layer.nil?
        halt 404, "No layer named #{ layer_name.inspect } exists."
      end # end
      unless current_user.update_layer?(layer)
        halt 401, 'Not authorized.'
      end # if

      LayerPostHandler.new(layer, params).handle()

      # Save or report errors.
      if layer.valid?()
        layer.save()
        redirect '/layers/'
      else
        haml :edit_layer, locals: { layer: layer }
      end # else
    end # do
  end # class
end # module

