# encoding: utf-8

module CitySDK
  class PodNodeDatumSerializer
    def initialize(options)
      @use_webservice = options.fetch('use_webservice', false)
    end # def

    def serialize(node_datum)
      data_pod = {} # Plain old data
      serialize_tags(node_datum, data_pod)
      serialize_modalities(node_datum, data_pod)
      serialize_data(node_datum, data_pod)
      create_pod(node_datum, data_pod)
    end # def

    private

    KEY_SEPARATOR = ':'

    def create_pod(node_datum, data_pod)
      layer_id = node_datum.fetch(:layer_id)
      layer = Layer.where(id: layer_id).first()
      { layer.name => data_pod }
    end # def

    def serialize_data(node_datum, data_pod)
      data = node_datum[:data]
      if @use_webservice
        layer = node_datum.layer
        web_service = layer.webservice
        unless web_service.nil? || web_service.empty?
          data = WebService.load(layer.id, node_datum.cdk_id, data)
        end # unless
      end # if
      data = data.to_hash()
      data_pod[:data] = nest(data)
      return # nothing
    end # def

    def serialize_modalities(node_datum, data_pod)
      modality_ids = node_datum[:modalities]
      modality_names = CitySDK::find_modality_names(modality_ids)
      data_pod[:modalities] = modality_names unless modality_names.empty?
      return # nothing
    end # def

    def serialize_tags(node_datum, data_pod)
      tags = node_datum[:tags]
      return if tags.nil? || tags.empty?
      data_pod[:tags] = tags
      return # nothing
    end # def

    def nest(h)
      xtra = {}
      h.each_key do |k|
        i = k.to_s.index(KEY_SEPARATOR)
        if i
          a = k.to_s.split(KEY_SEPARATOR)
          atonestedh(a, h[k], xtra)
          h.delete(k)
          h.delete(a[0]) if h[a[0]]
          xtra.each_key do |k|
            xtra[k]['->'] = h[k] if (h[k] and h[k].class == String)
          end # if
          h = h.merge(xtra)
        end # do
      end # do
      h
    end # def

    def atonestedh(a, v, h)
      g = h
      while a.length > 1
        aa = a.shift.to_sym()
        if g[aa].nil?
          g[aa] = {}
        elsif g[aa].class == String
          g[aa] = {'->' => g[aa]}
        end # elsif
        g = g[aa]
      end # while
      g[a[0].to_sym()] = v
      h
    end # def
  end # class
end # module
