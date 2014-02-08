# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layer/:layer_id/periodic' do |l|
      login_required
      @layer = layer = Layer[l]

      if layer.nil? || !current_user.update_layer?(layer)
        return
      end # if

      @layer.import_url = params['update_url']
      @layer.import_period = params['period']
      if !@layer.valid? || @layer.import_config.nil?
        @categories = @layer.cat_select
        redirect "/layer/#{l}/data"
      else
        @layer.save
        redirect "/layer/#{l}/data"
      end # else
    end # if
  end # class
end # module

