# encoding: utf-8

module CitySDK
  class TurtleSerializer < Serializer
    def initialize()
      super()
      @prefixes = Set.new()
    end # def

    def add_layer(layer, params, request)
      config = lambda { |key| CONFIG.fetch(key) }
      prefixes = Set.new
      rdf_url = config.call(:ep_rdf_url)
      prfs = [
        "@base <#{ rdf_url }#{ config.call(:ep_code) }/> ."
      ]
      prfs << "@prefix : <#{ rdf_url }> ."
      res = turtelize_layer(layer, params)
      prefixes.each do |p|
        prfs << "@prefix #{p} <#{ Prefix.where(prefix: p).first[:url] }> ."
      end
      parts = [
        prfs.join("\n"),
        '',
        res.join("\n")
      ]
      parts.join("\n")
    end # def

    def add_node(node, params)
      turtelize_node(node, params)
    end # def



    def serialize(params, request, pagination = {})
        parts = [
          prefixes().join("\n"),
          layer_props(params),
          @noderesults.join("\n")
        ]
        parts.join("\n")
    end # def

    protected

    def serialize_data_datum(node, node_datum, field, params)
      @noderesults = NodeDatum.turtelizeOneField(
        node[:cdk_id],
        node_datum,
        field,
        params
      )
    end # def

    private

    def layer_props(params)
      pr = []
      if params[:layerdataproperties]
        params[:layerdataproperties].each { |p| pr << p }
        pr << ""
      end # if
      pr
    end # def

    def prefixes()
      config = lambda { |key| CONFIG.fetch(key) }
      rdf_url = config.call(:ep_rdf_url)
      prfs = [
        "@base <#{ rdf_url }#{ config.call( :ep_code )}/> ."
      ]
      prfs << "@prefix : <#{ rdf_url }> ."
      @prefixes.each do |p|
        prefix = Prefix.where(prefix: p).first()
        unless prefix.nil?
          prfs << "@prefix #{ p } <#{ prefix[:url] }> ."
        end # unless
      end # do
      prfs << ''
    end # def

    def turtelize_layer(layer, params)
      @prefixes << 'rdf:'
      @prefixes << 'rdfs:'
      @prefixes << 'foaf:'
      @prefixes << 'geos:'
      triples = []

      triples << "<layer/#{layer.name}>"
      triples << "  a :Layer ;"

      d = layer.description ? layer.description.strip : ''
      if d =~ /\n/
        triples << "  rdfs:description \"\"\"#{d}\"\"\" ;"
      else
        triples << "  rdfs:description \"#{d}\" ;"
      end

      triples << "  :createdBy ["
      triples << "    foaf:name \"#{layer.organization.strip}\" ;"
      triples << "    foaf:mbox \"#{layer.owner.email.strip}\""
      triples << "  ] ;"


      if layer.data_sources
        layer.data_sources.each { |s|
          a = s.index('=') ? s[s.index('=')+1..-1] : s
          triples << "  :dataSource \"#{a}\" ;"
        }
      end

      res = CitySDK::LayerProperty.where(:layer_id => layer.id)
      res.each do |r|
        triples << "  :hasDataField ["
        triples << "    rdfs:label #{r.key} ;"
        triples << "    :valueType #{r.type} ;"
        if r.type =~ /(integer|float|double)/ && r.unit != ''
          triples << "    :valueUnit #{r.unit} ;"
        end
        if r.lang != '' && r.type == 'xsd:string'
          triples << "    :valueLanguange \"#{r.lang}\" ;"
        end
        if r.eqprop && r.eqprop != ''
          triples << "    owl:equivalentProperty \"#{r.eqprop}\" ;"
        end
        unless r.descr.empty?
          if r.descr =~ /\n/
            triples << "    rdfs:description \"\"\"#{r.descr}\"\"\" ;"
          else
            triples << "    rdfs:description \"#{r.descr}\" ;"
          end
        end
        triples[-1] = triples[-1][0...-1]
        triples << "  ] ;"
      end


      if params.has_key? 'geom' && !layer.bbox.nil?
        triples << '  geos:hasGeometry "' \
          + RGeo::WKRep::WKTGenerator.new.generate(
              CitySDKAPI.rgeo_factory.parse_wkb(layer.bbox)) \
          + '" ;'
      end

      triples[-1][-1] = '.'
      triples << ""
      @noderesults += triples
      triples
    end # def

    def turtelize_node(h, params)
      @prefixes << 'rdfs:'
      @prefixes << 'rdf:'
      @prefixes << 'geos:'
      @prefixes << 'dc:'
      @prefixes << 'owl:'
      @prefixes << 'lgdo:' if h[:layer_id] == 0
      triples = []

      if not @layers.include?(h[:layer_id])
        @layers << h[:layer_id]
        triples << "<layer/#{Layer.nameFromId(h[:layer_id])}> a :Layer ."
        triples << ""
      end

      triples << "<#{h[:cdk_id]}>"
      triples << "\t a :#{@node_types[h[:node_type]].capitalize} ;"
      if h[:name] and h[:name] != ''
        triples << "\t dc:title \"#{h[:name].gsub('"','\"')}\" ;"
      end
      layer_name = Layer.nameFromId(h[:layer_id])
      triples << "\t :createdOnLayer <layer/#{layer_name}> ;"

      if h[:modalities]
        h[:modalities].each { |modality|
          m = Modality.name_for_id(modality)
          triples << "\t :hasTransportmodality :transportModality_#{m} ;"
        }
      end

      if params.has_key? "geom"
        if h[:member_geometries] and h[:node_type] != 3
          triples << "\t geos:hasGeometry \"" \
            + RGeo::WKRep::WKTGenerator.new.generate(
                CitySDKAPI.rgeo_factory.parse_wkb(h[:member_geometries])) \
            + '" ;'
        elsif h[:geom]
          triples << "\t geos:hasGeometry \"" \
            + RGeo::WKRep::WKTGenerator.new.generate(
                CitySDKAPI.rgeo_factory.parse_wkb(h[:geom])) \
            + '" ;'
        end
      end

      if h[:node_data]
        t,d =  NodeDatum.turtelize(h[:cdk_id], h[:node_data], params)
        triples += t if t
        triples += d if d
      end

      @noderesults += triples
      if @noderesults[-1] && @noderesults[-1][-1] == ';'
        @noderesults[-1][-1]='.'
      end
      triples
    end # def

    def turtelize_node_data(cdk_id, h, params)
      triples = []
      gdatas = []
      if params[:layerdataproperties].nil?
        params[:layerdataproperties] = Set.new()
      end # if
      base_uri = "#{ cdk_id }/"
      h.each do |nd|
        gdatas += self.turtelize_one(nd, triples, base_uri, params, cdk_id)
      end # do
      return triples, gdatas
    end # def

    def process_predicate(n, params)
      p = params[:p]
      layer,field = p.split('/')
      if 0 == Layer.where(:name=>layer).count
        CitySDKAPI.do_abort(422,"Layer not found: 'layer'")
      end
      layer_id = Layer.idFromText(layer)
      nd = NodeDatum.where({:node_id => n[:id], :layer_id => layer_id}).first
      if nd
        case params[:request_format]
        when'application/json'
          @noderesults << {field => nd[:data][field.to_sym]}
        when'text/turtle'
          @noderesults = NodeDatum.turtelizeOneField(
            n[:cdk_id],
            nd,
            field,
            params
          )
        end
      end
    end # def


  end # class
end # module

