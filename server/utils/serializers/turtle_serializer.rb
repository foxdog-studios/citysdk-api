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
        prfs << "@prefix #{p} <#{Prefix.where(prefix: p).first[:url]}> ."
      end
      parts = [
        prfs.join("\n"),
        '',
        res.join("\n")
      ]
      parts.join("\n")
    end # def

    def serialize(params, request, pagination = {})
        parts = [
          prefixes().join("\n"),
          layer_props(params),
          @noderesults.join("\n")
        ]
        parts.join("\n")
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
  end # class
end # module

