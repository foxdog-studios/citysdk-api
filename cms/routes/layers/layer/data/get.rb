# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layer/:layer_id/data' do |layer_id|
      login_required

      @layer = Layer[layer_id]
      if @layer.nil? || current_user.id != @layer.owner_id || !current_user.admin?
        halt 401, 'Not authorized'
      end # if

      @period = @layer.period_select()
      @props = {}

      LayerProperty.where(:layer_id => layer_id).each do |property|
        @props[property.key] = property.serialize
      end # do

      @langSelect  = Layer.languageSelect
      @ptypeSelect = Layer.propertyTypeSelect
      @lType = @layer.rdf_type_uri
      @epSelect,@eprops = Layer.epSelect
      @props = @props.to_json

      if params.fetch(:nolayout)
        erb :layer_data, layout: false
      else
        erb :layer_data
      end # else
    end # do
  end # class
end # module

