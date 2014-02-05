require 'sequel/model'


class Layer < Sequel::Model
  many_to_one :owner, class: :SequelUser
  one_to_many :node_data, class: :NodeDatum

  plugin :validation_helpers
  plugin :json_serializer

  KEY_LAYER_NAMES = 'layer_names'
  KEY_LAYERS_AVAILABLE = 'layers_available'

  def validate
    super
    validates_presence [
      :category,
      :description,
      :name,
      :organization
    ]
    validates_unique :name
    validates_format /^\w+(\.\w+)*$/, :name
  end

  def self.memcache_key(id)
    "layer!!#{ id }"
  end

  def self.get_layer(id)
    self.ensure_layer_cache
    key = self.memcache_key(id)
    CitySDK_API.memcache_get(key)
  end

  def self.get_layer_names
    self.ensure_layer_cache
    CitySDK_API.memcache_get(KEY_LAYER_NAMES)
  end

  def self.ensure_layer_cache
    unless CitySDK_API.memcache_get(KEY_LAYERS_AVAILABLE)
      self.getLayerHashes
    end
  end

  def self.get_validity(id)
    layer = self.get_layer(id)
    if layer[:realtime]
      return true, layer[:update_rate]
    else
      return false, layer[:validity]
    end
  end

  def serialize(params, request)
    case params[:request_format]
    when 'text/turtle'
      prefixes = Set.new
      prfs = ["@base <#{::CitySDK_API::CDK_BASE_URI}#{::CitySDK_API::Config[:ep_code]}/> ."]
      prfs << "@prefix : <#{::CitySDK_API::CDK_BASE_URI}> ."
      res = turtelize(params)
      prefixes.each do |p|
        puts p
        prfs << "@prefix #{p} <#{Prefix.where(:prefix => p).first[:url]}> ."
      end
      return [prfs.join("\n"),"",res.join("\n")].join("\n")
    when 'application/json'
      return { :status => 'success',
        :url => request.url,
        :results => [ make_hash(params) ]
      }.to_json
    end
  end

  def turtelize(params)
    @@prefixes << 'rdf:'
    @@prefixes << 'rdfs:'
    @@prefixes << 'foaf:'
    @@prefixes << 'geos:'
    triples = []

    triples << "<layer/#{name}>"
    triples << "  a :Layer ;"

    d = description ? description.strip : ''
    if d =~ /\n/
      triples << "  rdfs:description \"\"\"#{d}\"\"\" ;"
    else
      triples << "  rdfs:description \"#{d}\" ;"
    end

    triples << "  :createdBy ["
    triples << "    foaf:name \"#{organization.strip}\" ;"
    triples << "    foaf:mbox \"#{owner.email.strip}\""
    triples << "  ] ;"


    if data_sources
      data_sources.each { |s|
        a = s.index('=') ? s[s.index('=')+1..-1] : s
        triples << "  :dataSource \"#{a}\" ;"
      }
    end

    res = LayerProperty.where(:layer_id => id)
    res.each do |r|
      triples << "  :hasDataField ["
      triples << "    rdfs:label #{r.key} ;"
      triples << "    :valueType #{r.type} ;"
      triples << "    :valueUnit #{r.unit} ;" if r.type =~ /(integer|float|double)/ and r.unit != ''
      triples << "    :valueLanguange \"#{r.lang}\" ;" if r.lang != '' and r.type == 'xsd:string'
      triples << "    owl:equivalentProperty \"#{r.eqprop}\" ;" if r.eqprop and r.eqprop != ''
      if not r.descr.empty?
        if r.descr =~ /\n/
          triples << "    rdfs:description \"\"\"#{r.descr}\"\"\" ;"
        else
          triples << "    rdfs:description \"#{r.descr}\" ;"
        end
      end
      triples[-1] = triples[-1][0...-1]
      triples << "  ] ;"
    end


    if params.has_key? "geom" and !bbox.nil?
      triples << "  geos:hasGeometry \"" +  RGeo::WKRep::WKTGenerator.new.generate( CitySDK_API.rgeo_factory.parse_wkb(bbox) )  + "\" ;"
    end

    triples[-1][-1] = '.'
    triples << ""
    @@noderesults += triples
    triples
  end

  def make_hash(params)
    h = {
      :name => name,
      :category => category,
      :organization => organization,
      :owner => owner.email,
      :description => description,
      :data_sources => data_sources ? data_sources.map { |s| s.index('=') ? s[s.index('=')+1..-1] : s } : [],
      :imported_at => imported_at
    }

    res = LayerProperty.where(:layer_id => id)
    h[:fields] = [] if res.count > 0
    res.each do |r|
      a = {
        :key => r.key,
        :type => r.type
      }
      a[:valueUnit]      = r.unit if r.type =~ /(integer|float|double)/ and r.unit != ''
      a[:valueLanguange] = r.lang if r.lang != '' and r.type == 'xsd:string'
      a[:equivalentProperty] = r.eqprop if r.eqprop and r.eqprop != ''
      a[:description]    = r.descr if not r.descr.empty?
      h[:fields] << a
    end

    if sample_url
      h[:sample_url] = sample_url
    end

    if realtime
      h[:update_rate] = update_rate
    # else
    #   h[:validity] = [validity.begin, validity.end] if validity
    end

    if !bbox.nil? and params.has_key? 'geom'
       h[:bbox] = RGeo::GeoJSON.encode(CitySDK_API.rgeo_factory.parse_wkb(bbox))
    end
    @@noderesults << h
    h
  end

  def self.idFromText(p)
    # Accepts full layer names and layer names
    # with wildcards after dot layer separators:
    #    cbs.*
    case p
    when Array
      return p.map do |name| self.idFromText(name) end.flatten.uniq
    when String
      layer_names = self.get_layer_names
      if layer_names
        if p.include? "*"
          # wildcards can only be used once, on the end of layer specifier after "." separator
          if p.length >= 3 and p.scan("*").size == 1 and p.scan(".*").size == 1 and p[-2,2] == ".*"
            prefix = p[0..(p.index("*") - 1)]
            return layer_names.select{|k,v| k.start_with? prefix}.values
          else
            CitySDK_API.do_abort(422,"You can only use wildcards in layer names directly after a name separator (e.g. osm.*)")
          end
        else
          return layer_names[p]
        end
      else
        # No layer names available, something went wrong
        CitySDK_API.do_abort(500,"Layer cache unavailable")
      end
    end
  end

  def self.nameFromId(id)
    layer = self.get_layer(id)
    layer[:name]
  end

  ##########################################################################################
  # Real-time/web service layers:
  ##########################################################################################

  def self.isRealtime?(id)
    layer = self.get_layer(id)
    layer[:realtime]
  end

  def self.isWebservice?(id)
    layer = self.get_layer(id)

    webservice = layer[:webservice]
    if layer[:name] == 'ns'
      webservice = false
    end

    return (webservice and webservice.length > 0)
  end

  def self.getWebserviceUrl(id)
    layer = self.get_layer(id)
    layer[:webservice]
  end

  def self.getData(id, node_id, data)
    WebService.load(id, node_id, data)
  end

  def self.getDataTimeout(id)
    layer = self.get_layer(id)
    layer["update_rate"] || 3000
  end

  ##########################################################################################
  # Initialize layers hash:
  ##########################################################################################

  def self.getLayerHashes
    names = {}
    Layer.all.each do |l|
      id = l[:id]
      name = l[:name]
      # Save layer data in memcache without expiration
      key = self.memcache_key(id)
      CitySDK_API.memcache_set(key, l.values, 0)
      names[name] = id
    end

    CitySDK_API.memcache_set(KEY_LAYER_NAMES, names, 0)
    CitySDK_API.memcache_set(KEY_LAYERS_AVAILABLE, true, 0)
  end
end

