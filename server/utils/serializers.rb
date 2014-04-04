# encoding: utf-8

module CitySDK
  class Serializer
    def initialize()
      @node_types = ['node','route','ptstop','ptline']
      @noderesults = []
      @prefixes = Set.new
      @layers = []
    end

    def add_node(node, params)
      case params[:request_format]
      when 'application/json'
        hash_node(node, params)
      when 'text/turtle'
        turtelize_node(node, params)
      end
    end

    def hash_node(h, params)
      if h[:node_data]
        h[:layers] = NodeDatum.serialize(h[:cdk_id], h[:node_data], params)
      end
      # members not directly exposed,
      # call ../ptstops form members of route, f.i.
      h.delete(:members)

      h[:layer] = Layer.nameFromId(h[:layer_id])
      if h[:name].nil?
        h[:name] = ''
      end
      if params.has_key? "geom"
        if h[:member_geometries] && h[:node_type] != 3
          h[:geom] = RGeo::GeoJSON.encode(
            CitySDKAPI.rgeo_factory.parse_wkb(h[:member_geometries]))
        elsif h[:geom]
          h[:geom] = RGeo::GeoJSON.encode(
            CitySDKAPI.rgeo_factory.parse_wkb(h[:geom]))
        end
      else
        h.delete(:geom)
      end

      if h[:modalities]
        h[:modalities] = h[:modalities].map { |m| Modality.name_for_id(m) }
      else
        h.delete(:modalities)
      end

      h.delete(:related) if h[:related].nil?
      h.delete(:member_geometries)
      h[:node_type] = @node_types[h[:node_type]]
      h.delete(:layer_id)
      h.delete(:id)
      h.delete(:node_data)
      h.delete(:created_at)
      h.delete(:updated_at)

      if h.has_key? :collect_member_geometries
        h.delete(:collect_member_geometries)
      end
      @noderesults << h
      h
    end


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


    def add_layer(layer, params, request)
      case params[:request_format]
      when 'text/turtle'
        config = lambda { |key| CONFIG.fetch(key) }
        prefixes = Set.new
        rdf_url = config.call(:ep_rdf_url)
        prfs = [
          "@base <#{rdf_url}#{config.call(:ep_code)}/> ."
        ]
        prfs << "@prefix : <#{rdf_url}> ."
        res = turtelize_layer(layer, params)
        prefixes.each do |p|
          prfs << "@prefix #{p} <#{Prefix.where(:prefix => p).first[:url]}> ."
        end
        return [prfs.join("\n"),"",res.join("\n")].join("\n")
      when 'application/json'
        return { :status => 'success',
          :url => request.url,
          :results => [ layer.make_hash(params) ]
        }.to_json
      end
    end

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
    end


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
          @noderesults = NodeDatum.turtelizeOneField(n[:cdk_id],
                                                      nd,
                                                      field,
                                                      params)
        end
      end
    end

    def prefixes
      config = lambda { |key| CONFIG.fetch(key) }
      rdf_url = config.call(:ep_rdf_url)
      prfs = [
        "@base <#{rdf_url}#{config.call(:ep_code)}/> ."
      ]
      prfs << "@prefix : <#{rdf_url}> ."
      @prefixes.each do |p|
        prefix = Prefix.where(:prefix => p).first()
        unless prefix.nil?
          prfs << "@prefix #{p} <#{prefix[:url]}> ."
        end
      end
      prfs << ""
    end

    def layer_props(params)
      pr = []
      if params[:layerdataproperties]
        params[:layerdataproperties].each do |p|
          pr << p
        end
        pr << ""
      end
      pr
    end

    def serialize(params,request, pagination = {})
      case params[:request_format]
      when 'application/json'
        {
          status: 'success',
          url: request.url
        }.merge(pagination).merge({
          results: @noderesults
        }).to_json()
      when 'text/turtle'
        [
          prefixes().join("\n"),
          layer_props(params),
          @noderesults.join("\n")
        ].join("\n")
      end
    end
  end # class
end # module

