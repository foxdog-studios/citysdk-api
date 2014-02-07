# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layer/edit/:layer_id' do |l|
      login_required
      @layer = layer = Layer[l]
      user = current_user

      if layer.nil? || (layer.owner_id != user.id && !user.admin?)
        halt 401, 'Not authorized.'
      end # if

      @layer.description = params['description']
      params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
      params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?
      if( params['realtime'] )
        @layer.realtime = true;
        @layer.update_rate = params['update_rate'].to_i
      else
        @layer.realtime = false;
        @layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
      end
      ds = []; i = 0;
      while params["data_sources"][i.to_s]
        if params["data_sources"][i.to_s] != ''
          ds << params["data_sources"][i.to_s]
        end
        i += 1
      end if params["data_sources"]
      ds << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
      @layer.data_sources = ds
      @layer.organization = params['organization']
      @layer.category = params['catprefix'] + '.' + params['category']

      @layer.webservice = params['wsurl']
      @layer.update_rate = params['update_rate']

      @layer.sample_url = params['sample_url'] if params['sample_url'] and params['sample_url'] != ''


      if !@layer.valid?
        @categories = @layer.cat_select
        erb :edit_layer
      else
        @layer.save
        api = CitySDK::API.new(@api_server)
        api.get('/layers/reload__')
        redirect '/'
      end
    end # do
  end # class
end # module

