# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    delete '/layer/:layer_id' do |l|
      login_required
      @layer = layer = Layer[l]

      if layer.nil? || !current_user.can_delete_layer(layer)
        redirect '/'
      end

      url = "/layer/#{@layer.name}"
      par = []
      params.each_key { par << "#{k}=#{params[k]}" }
      url += "?" + par.join("&") if par.length > 0

      # XXX: User of old API client.
      api = CitySDK::API.new(@api_server)
      api.authenticate(session[:e],session[:p]) do
        api.delete(url)
      end # do

      get_layers
      redirect "/"
    end # do
  end # class
end # module

