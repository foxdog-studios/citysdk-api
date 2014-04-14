# encoding: utf-8

module CitySDK
  class LayerPostHandler
    def initialize(layer, params)
      @layer = layer
      @params = params
    end # def

    def handle()
      update_category()
      update_data_sources()
      update_description()
      update_organization()
      update_realtime()
      update_sample_url()
      update_update_rate()
      update_validity()
      update_webservice()
    end # def

    private

    def validity?()
      !(get_validity_from().nil? || get_validity_to().nil?)
    end # def


    # ======================================================================
    # = Getters                                                            =
    # ======================================================================

    def get_category()
      get('category')
    end # def

    def get_data_sources()
      data_sources = get_or('data_sources', []).to_a()
      data_sources.map! { |index, data_source|  [index.to_i, data_source] }
      data_sources.sort!().map! { |_, data_source| data_source }
      # This is the possible new data source.
      data_sources_x = try_get('data_sources_x')
      data_sources << data_sources_x unless data_sources_x.nil?
      data_sources.reject! { |data_source| data_source.empty? }
    end # def

    def get_description()
      get('description')
    end # def

    def get_organization()
      get('organization')
    end # def

    def get_realtime()
      key?('realtime')
    end # def

    def get_sample_url()
      sample_url = try_get('sample_url')
      return if sample_url.nil? || sample_url.empty?
      sample_url
    end # def

    def get_update_rate()
      update_rate = try_get('update_rate')
      update_rate = update_rate.to_i() unless update_rate.nil?
      update_rate
    end # def

    def get_validity()
      return unless validity?()
      "[#{ get_validity_from() }, #{ get_validity_to() }]"
    end # def

    def get_validity_from()
      try_get('validity_from')
    end # def

    def get_validity_to()
      try_get('validity_to')
    end # def

    def get_webservice()
      try_get('wsurl')
    end # def


    # ======================================================================
    # = Updaters                                                           =
    # ======================================================================

    def update_category()
      @layer.category = get_category()
    end # def

    def update_data_sources()
      @layer.data_sources = get_data_sources()
    end # def

    def update_description()
      @layer.description = get_description()
    end # def

    def update_organization()
      @layer.organization = get_organization()
    end # def

    def update_realtime()
      @layer.realtime = get_realtime()
    end # def

    def update_sample_url()
      @layer.sample_url = get_sample_url()
    end # def

    def update_update_rate()
      @layer.update_rate = get_update_rate()
    end # def

    def update_validity()
      @layer.validity = get_validity()
    end # def

    def update_webservice()
      @layer.webservice = get_webservice()
    end # def


    # ======================================================================
    # = Helpers                                                            =
    # ======================================================================

    def key?(key)
      @params.key?(key)
    end # def

    def get(key)
      @params.fetch(key)
    end # def

    def try_get(key)
      @params[key]
    end # def

    def get_or(key, default)
      @params.fetch(key, default)
    end # def
  end # class
end # module

