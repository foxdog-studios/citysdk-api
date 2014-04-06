# encoding: utf-8

module CitySDK
  class TurtleSerializer < Serializer
    def self.create(options)
      TurtleSerializer.new(
        TurtleDirectiveSerializer.new(options),
        TurtleLayerSerializer.new(options),
        TurtleNodeSerializer.new(options)
      )
    end # def

    def initialize(directive_serializer, layer_serializer, node_serializer)
      super()

      @layers = {}
      @nodes = {}

      @directive_serializer = directive_serializer
      @layer_serializer = layer_serializer
      @node_serializer = node_serializer
    end # def

    def add_layer(layer)
      @layers[layer.id] = layer
    end # def

    def add_node(node)
      @nodes[node.fetch(:id)] = node
      add_layer_for_node(node)
    end # def

    def serialize()
      [
        serialize_directives(),
        serialize_layers(),
        serialize_nodes()
      ].join("\n\n")
    end # def

    protected

    def serialize_node_datum_field(node, node_datum, field, params)
      cdk_id = node[:cdk_id]
      field = turtelize_one_field(cdk_id, node_datum, field, params)
      @noderesults = field
    end # def

    private

    def add_layer_for_node(node)
      layer_id = node.fetch(:layer_id)
      layer = Layer.where(id: layer_id).first()
      add_layer(layer)
    end # def

    def serialize_directives()
      @directive_serializer.serialize()
    end # def

    def serialize_layers()
      layers = @layers.values().map do |layer|
        @layer_serializer.serialize(layer)
      end # do
      layers.join("\n\n")
    end # def

    def serialize_nodes()
      nodes = @nodes.values().map { |node| @node_serializer.serialize(node) }
      nodes.join("\n\n")
    end # def

    def layer_props(params)
      pr = []
      if params[:layerdataproperties]
        params[:layerdataproperties].each { |p| pr << p }
        pr << ""
      end # if
      pr
    end # def


    def turtelize_node_data(cdk_id, h, params)
      triples = []
      gdatas = []
      if params[:layerdataproperties].nil?
        params[:layerdataproperties] = Set.new()
      end # if
      base_uri = "#{ cdk_id }/"
      h.each do |nd|
        gdatas += turtelize_one(nd, triples, base_uri, params, cdk_id)
      end # do
      return triples, gdatas
    end # def

    def turtelize_one(nd, triples, base_uri, params, cdk_id)
      datas = []
      layer_id = nd[:layer_id]
      name = Layer.nameFromId(layer_id)
      layer = Layer.where(:id=>layer_id).first
      subj = base_uri + name

      if layer_id == 0
        osmprops(nd[:data].to_hash, datas, triples, params)
      else
        if layer.rdf_type_uri and layer.rdf_type_uri != ''
          if layer.rdf_type_uri =~ /^http:/
            triples << "\t a <#{layer.rdf_type_uri}> ;"
          else
            @@prefixes << $1 if layer.rdf_type_uri =~ /^([a-z]+\:)/
            triples << "\t a  #{layer.rdf_type_uri} ;"
          end
        end

        if Layer.isWebservice?(layer_id) and !params.has_key?('skip_webservice')
          nd[:data] = WebService.load(layer_id, cdk_id, nd[:data])
        end

        nd[:data].to_hash.each do |k,v|

          res = LayerProperty.where({:layer_id => layer_id, :key => k.to_s }).first
          if res
            lang = res[:lang]  == '' ? nil : res[:lang]
            type = res[:type]  == '' ? nil : res[:type]
            unit = res[:unit]  == '' ? nil : res[:unit]
            desc = res[:descr] == '' ? nil : res[:descr]
            eqpr = res[:eqprop] == '' ? nil : res[:eqprop]
          else
            lang = type = unit = desc = eqpr = nil
          end
          prop = "<#{name}/#{k.to_s}>"

          lp  = "#{prop}"
          lp += "\n\t :definedOnLayer <layer/#{Layer.nameFromId(layer_id)}> ;"
          lp += "\n\t rdfs:subPropertyOf :layerProperty ;"
          lp += "\n\t owl:equivalentProperty #{eqpr} ;" if eqpr

          @@prefixes << $1 if eqpr and (eqpr =~ /^([a-z]+\:)/)

          if desc and desc =~ /\n/
            lp += "\n\t rdfs:description \"\"\"#{desc}\"\"\" ;"
          elsif desc
            lp += "\n\t rdfs:description \"#{desc}\" ;"
          end
          lp += "\n\t :hasValueUnit #{unit} ;" if unit and type =~ /xsd:(integer|float|double)/
          lp[-1] = '.'
          params[:layerdataproperties] << lp

          s  = "\t #{prop} \"#{v}\""
          s += "^^#{type}" if type and type !~ /^xsd:string/
          s += "#{lang}" if lang and type == 'xsd:string'


          if type =~ /xsd:anyURI/i
            s  = "\t #{prop} <#{v}>"
          else
            s  = "\t #{prop} \"#{v}\""
            s += "^^#{type}" if type and type !~ /^xsd:string/
            s += "#{lang}" if lang and type == 'xsd:string'
          end
          datas << s + " ;"
        end
      end

      if datas.length > 1
        datas[-1][-1] = '.'
        datas << ""
      else
        datas = []
      end # else
      return datas
    end # def

    def turtelize_one_field(cdk_id, nd, field, params)
      ret = []

      is_webservice = Layer.isWebservice?(nd[:layer_id])
      use_webservice = !params.key?('skip_webservice')
      if is_webservice && use_webservice
        nd[:data] = WebService.load(nd[:layer_id], cdk_id, nd[:data])
      end # if

      name = Layer.nameFromId(nd[:layer_id])
      prop = "<#{name}/#{field}>"

      res = LayerProperty.where(layer_id: nd[:layer_id], key: field).first()
      if res
        lang = res[:lang] == '' ? nil : res[:lang]
        type = res[:type] == '' ? nil : res[:type]
        unit = res[:unit] == '' ? nil : res[:unit]
        desc = res[:descr] == '' ? nil : res[:descr]
        eqpr = res[:eqprop] == '' ? nil : res[:eqprop]
      else
        lang = type = unit = desc = eqpr = nil
      end # else

      @prefixes << $1 if eqpr && (eqpr =~ /^([a-z]+\:)/)
      @prefixes << $1 if type && (type =~ /^([a-z]+\:)/)

      @prefixes << 'xsd:'
      @prefixes << 'rdfs:'

      lp  = "#{prop}"
      lp += "\n\t :definedOnLayer <layer/#{Layer.nameFromId(nd[:layer_id])}> ;"
      lp += "\n\t rdfs:subPropertyOf :layerProperty ;"
      lp += "\n\t owl:equivalentProperty #{eqpr} ;" if eqpr

      if desc && desc =~ /\n/
        lp += "\n\t rdfs:description \"\"\"#{ desc }\"\"\" ;"
      elsif desc
        lp += "\n\t rdfs:description \"#{ desc }\" ;"
      end # elseif

      if unit && type =~ /xsd:(integer|float|double)/
        lp += "\n\t :hasValueUnit #{ unit.gsub(/^csdk\:/, ':') } ;"
      end # if

      lp[-1] = '.'
      ret << lp
      ret << ""
      ret << "<#{cdk_id}> a :Node ;"

      if type =~ /xsd:anyURI/i
        s  = "\t #{prop} <#{nd[:data][field]}>"
      else
        s  = "\t #{prop} \"#{nd[:data][field]}\""
        s += "^^#{type}" if type and type !~ /^xsd:string/
        s += "#{lang}" if lang and type == 'xsd:string'
      end # else

      ret << s + " ."
      return ret
    end # def

    # deal with osm rdf mapping separately...
    def osmprops(h, datas, triples, params)
      h.each do |k,v|
        t = osmprop(k, v)
        if t
          triples << t
        else
          prop = "<osm/#{ k.to_s() }>"
          param = "#{ prop } rdfs:subPropertyOf :layerProperty ."
          params[:layerdataproperties] << param
          datas << "\t #{ prop } \"#{ v }\" ;"
        end # else
      end # do
    end # def

    def osmprop(k, v)
      o = OSMProps.where(key: k, val: v ).first()
      return "\t #{ o[:type] } #{ o[:uri] } ;" unless o.nil?

      o = OSMProps.where(key: k)
          .where(Sequel.~(lang: nil))
          .first()
      return "\t #{ o[:uri] } \"#{ v }\"@#{ o[:lang] } ;" unless o.nil?

      o = OSMProps
        .where(type: 'string', key: k)
        .where(Sequel.~(uri: nil))
        .first()
      return "\t #{ o[:uri] } \"#{ v }\" ;" unless o.nil?

      o = OSMProps
        .where(type: 'a', key: k)
        .where(Sequel.~(uri: nil))
        .first()
      return "\t #{ o[:type] } #{ o[:uri] } ;" unless o.nil?

      o = OSMProps
        .where(key: k)
        .where(Sequel.~(type: nil))
        .first()
      unless o.nil?
        return "\t #{ o[:uri] } \"#{ v }\"^^xsd:#{ o[:type] } ;"
      end # unless

      nil
    end # def

    KEY_SEPARATOR = ':'

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
          end
          h = h.merge(xtra)
        end
      end
      h
    end

    def atonestedh(a, v, h)
      g = h
      while a.length > 1
        aa = a.shift.to_sym
        if g[aa].nil?
          g[aa] = {}
        elsif g[aa].class == String
          g[aa] = {'->' => g[aa]}
        end # elsif
        g = g[aa]
      end # while
      g[a[0].to_sym] = v
      h
    end # def
  end # class
end # module

