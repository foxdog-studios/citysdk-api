# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/layers/:layer_name/' do |layer_name|
      layer = Layer.for_name(layer_name)

      if layer.nil?
        halt 404, "No layer named #{ layer_name.inspect } exists."
      end # end

      user = current_user

      unless user.update_layer?(layer)
        halt 401, 'Not authorized.'
      end # if

      # Description
      layer.description = params.fetch('description')

      # Realtime
      layer.realtime = params.key?('realtime')

      if layer.realtime
        # Update rate
        layer.update_rate = params.fetch('update_rate').to_i

      else
        # Validity
        get_valid = lambda do |key|
          valid = params.fetch("validity_#{ key }") do
            Time.now.strftime('%Y-%m-%d')
          end # do
        end # do
        valid_from = get_valid.call('from')
        valid_to = get_valid.call('to')
        layer.validity = "[#{ valid_from }, #{ valid_to }]"
      end # else

      # Data sources
      data_sources = params.fetch('data_sources', []).to_a
      data_sources.map! { |index, data_source|  [index.to_i, data_source] }
      data_sources.sort!.map! { |_, data_source| data_source }

      # XXX: What is this?
      data_sources_x = params['data_sources_x']
      data_sources << data_sources_x unless data_sources_x.nil?

      data_sources.reject! { |data_source| data_source.empty? }
      layer.data_sources = data_sources

      # Organization
      layer.organization = params.fetch('organization')

      # Category
      layer.category = params.fetch('category')

      # Other attributes
      layer.webservice = params['wsurl']

      # Update rate
      layer.update_rate = params['update_rate']

      # Sample URL
      sample_url = params['sample_url']
      unless sample_url.nil? || sample_url.empty?
        layer.sample_url = sample_url
      end # if

      # Save or report errors.
      if layer.valid?
        layer.save
        redirect '/layers/'
      else
        haml :edit_layer, locals: { layer: layer }
      end # else
    end # do
  end # class
end # module

