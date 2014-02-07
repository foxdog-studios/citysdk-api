# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layer/create' do
      login_required

      return unless current_user.can_create_layer

      @layer = Layer.new
      @layer.owner_id = current_user.id

      if( params['prefix'] && params['prefix'] != '' )
        @layer.name = params['prefix'] + '.' + params['name']
      elsif (params['prefixc']  && params['prefixc'] != '' )
        @layer.name = params['prefixc'] + '.' + params['name']
      else
        @layer.name = params['name']
      end

      params['validity_from'] = Time.now.strftime('%Y-%m-%d') if params['validity_from'].nil?
      params['validity_to'] = Time.now.strftime('%Y-%m-%d') if params['validity_to'].nil?

      @layer.description = params['description']
      @layer.update_rate = params['update_rate'].to_i
      @layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
      @layer.realtime = params['realtime'] ? true : false;
      @layer.data_sources = []
      @layer.data_sources << params["data_sources_x"] if params["data_sources_x"] && params["data_sources_x"] != ''
      @layer.organization = params['organization']
      @layer.category = params['catprefix'] + '.' + params['category']
      @layer.webservice = params['wsurl']
      @layer.update_rate = params['update_rate']

      if !@layer.valid?
        @prefix = params['prefixc']
        @layer.name = params['name']
        @categories = @layer.cat_select
        erb :new_layer
      else
        @layer.save
        get_layers
        erb :layers
      end # if
    end # do
  end # class
end # module

