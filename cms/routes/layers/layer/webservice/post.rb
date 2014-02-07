# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layer/:layer_id/webservice' do |l|
      login_required
      @layer = layer = Layer[l]

      if layer.nil? || !current_user.can_update_layer(layer)
        return
      end # if

      @layer.webservice = params['wsurl']
      @layer.update_rate = params['update_rate']
      if !@layer.valid?
        @categories = @layer.cat_select
        redirect "/layer/#{l}/data"
      else
        @layer.save
        redirect "/layer/#{l}/data"
      end # else
    end # do
  end # class
end # module

