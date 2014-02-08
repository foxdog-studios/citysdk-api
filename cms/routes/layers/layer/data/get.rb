# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layers/:layer_name/data' do |layer_name|
      login_required

      layer = Layer.get_by_name(layer_name)
      if layer.nil? || !current_user.can_retrieve_layer(layer)
        halt 401, 'Not authorized'
      end # if

      @props = {}

      LayerProperty.where(layer_id: layer.id).each do |property|
        @props[property.key] = property.serialize
      end # do

      @langSelect  = Layer.languageSelect
      @ptypeSelect = Layer.propertyTypeSelect
      @lType = layer.rdf_type_uri
      @epSelect, @eprops = Layer.epSelect
      @props = @props.to_json

      haml :layer_data, locals: { layer: layer }
    end # do
  end # class
end # module

