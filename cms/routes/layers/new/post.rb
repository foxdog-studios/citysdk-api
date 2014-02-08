# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/new' do
      owner = current_user
      halt 403 unless owner.create_layer?

      layer = Layer.new
      layer.owner_id = owner.id

      # Name
      name = params.fetch('name')
      prefix = params['prefix']
      prefixc = params['prefixc']

      layer.name =
        if !prefix.nil? && !prefix.empty?
          "#{ prefix }.#{ name }"
        elsif !prefixc.nil? && !prefixc.empty?
          "#{ prefixc }.#{ name }"
        else
          name
        end # else

      if params['validity_from'].nil?
        params['validity_from'] = Time.now.strftime('%Y-%m-%d')
      end # if

      if params['validity_to'].nil?
        params['validity_to'] = Time.now.strftime('%Y-%m-%d')
      end # if

      layer.description = params['description']
      layer.update_rate = params['update_rate'].to_i
      layer.validity = "[#{params['validity_from']}, #{params['validity_to']}]"
      layer.realtime = params['realtime'] ? true : false;
      layer.data_sources = []

      if params["data_sources_x"] && params["data_sources_x"] != ''
        layer.data_sources << params["data_sources_x"]
      end # end

      layer.organization = params['organization']
      layer.category = params['category']
      layer.webservice = params['wsurl']
      layer.update_rate = params['update_rate']

      if layer.valid?
        layer.save
        redirect "/layers/"
      else
        haml :new_layer, locals: { layer: layer }
      end # if
    end # do
  end # class
end # module

