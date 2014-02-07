# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layer/:layer_id/edit' do |l|
      login_required
      @layer = layer = Layer[l]

      if layer.nil? || !current_user.can_update_layer(layer)
        halt 401, 'Not authorized'
      end # if

      @layer.data_sources = [] if @layer.data_sources.nil?
      @categories = @layer.cat_select
      @webservice = @layer.webservice and @layer.webservice != ''
      erb :edit_layer
    end # do
  end # class
end # module

