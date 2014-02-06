require 'sequel/model'
require 'sequel/plugins/serialization'
require 'set'
require 'json'

Sequel::Inflections.uncountable 'node_data'

class NodeDatum < Sequel::Model
  many_to_one :node
  many_to_one :layer

  plugin :validation_helpers

  # hash = {
  #   :name => :plop,
  #   :id => 123,
  #   'addr1:str'=>'kj',
  #   'addr1:num'=>1
  # }
  #

  KEY_SEPARATOR = ':'

  def self.atonestedh(a,v,h)
    begin
      g = h
      while(a.length > 1 )
        aa = a.shift.to_sym
        if g[aa].nil?
          g[aa] = {}
        elsif g[aa].class == String
          g[aa] = {'->' => g[aa]}
        end
        g = g[aa]
      end
      g[a[0].to_sym] = v
      h
    rescue => e
      puts e.message;
    end
  end

  def self.nest(h)
    xtra = {}
    h.each_key do |k|
      i = k.to_s.index(KEY_SEPARATOR)
      if i
        a = k.to_s.split(KEY_SEPARATOR)
        atonestedh(a,h[k],xtra)
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


  def self.osmprop(k,v)
    o = OSMProps.where({:key => k,:val => v}).first
    return "\t #{o[:type]} #{o[:uri]} ;" if(o)

    o = OSMProps.where(:key => k).where(Sequel.~(:lang => nil)).first
    return "\t #{o[:uri]} \"#{v}\"@#{o[:lang]} ;" if(o)

    o = OSMProps.where({:type => 'string', :key => k}).where(Sequel.~(:uri => nil)).first
    return "\t #{o[:uri]} \"#{v}\" ;" if(o)

    o = OSMProps.where({:type => 'a', :key => k}).where(Sequel.~(:uri => nil)).first
    return "\t #{o[:type]} #{o[:uri]} ;" if(o)

    o = OSMProps.where(:key => k).where(Sequel.~(:type => nil)).first
    return "\t #{o[:uri]} \"#{v}\"^^xsd:#{o[:type]} ;" if(o)

    nil
  end

  # deal with osm rdf mapping separately...
  def self.osmprops(h,datas,triples,params)
    h.each do |k,v|
      t = self.osmprop(k,v)
      if t
        triples << t
      else
        prop = "<osm/#{k.to_s}>"
        params[:layerdataproperties] << "#{prop} rdfs:subPropertyOf :layerProperty ."
        datas << "\t #{prop} \"#{v}\" ;"
      end
    end # h.each
  end

  def self.turtelize_one(nd,triples,base_uri,params,cdk_id)
    datas = []
    layer_id = nd[:layer_id]
    name = Layer.nameFromId(layer_id)
    layer = Layer.where(:id=>layer_id).first
    subj = base_uri + name

    # datas << "<#{subj}>"

    if layer_id == 0

      osmprops(nd[:data].to_hash,datas,triples,params)

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
    end
    return datas
  end

  def self.turtelizeOneField(cdk_id,nd,field,params)

    ret = []

    if Layer.isWebservice?(nd[:layer_id]) and !params.has_key?('skip_webservice')
      nd[:data] = WebService.load(nd[:layer_id], cdk_id, nd[:data])
    end

    name = Layer.nameFromId(nd[:layer_id])
    prop = "<#{name}/#{field}>"

    res = LayerProperty.where({:layer_id => nd[:layer_id], :key => field }).first
    if res
      lang = res[:lang]  == '' ? nil : res[:lang]
      type = res[:type]  == '' ? nil : res[:type]
      unit = res[:unit]  == '' ? nil : res[:unit]
      desc = res[:descr] == '' ? nil : res[:descr]
      eqpr = res[:eqprop] == '' ? nil : res[:eqprop]
    else
      lang = type = unit = desc = eqpr = nil
    end

    @@prefixes << $1 if eqpr and (eqpr =~ /^([a-z]+\:)/)
    @@prefixes << $1 if type and (type =~ /^([a-z]+\:)/)

    @@prefixes << 'xsd:'
    @@prefixes << 'rdfs:'

    # puts type
    # if type =~ /^\w+\:/
    #   puts $0
    # end
    #
    # puts unit
    # if unit =~ /^\w+\:/
    #   puts $0
    # end
    #
    # @@prefixes << $1 if type =~ /^\w+\:/


    lp  = "#{prop}"
    lp += "\n\t :definedOnLayer <layer/#{Layer.nameFromId(nd[:layer_id])}> ;"
    lp += "\n\t rdfs:subPropertyOf :layerProperty ;"
    lp += "\n\t owl:equivalentProperty #{eqpr} ;" if eqpr


    if desc and desc =~ /\n/
      lp += "\n\t rdfs:description \"\"\"#{desc}\"\"\" ;"
    elsif desc
      lp += "\n\t rdfs:description \"#{desc}\" ;"
    end
    lp += "\n\t :hasValueUnit #{unit.gsub(/^csdk\:/,':')} ;" if unit and type =~ /xsd:(integer|float|double)/
    lp[-1] = '.'

    ret << lp
    ret << ""

    # ret << "<#{cdk_id}> a :#{@@node_types[h[:node_type]].capitalize} ;"
    ret << "<#{cdk_id}> a :Node ;"

    if type =~ /xsd:anyURI/i
      s  = "\t #{prop} <#{nd[:data][field]}>"
    else
      s  = "\t #{prop} \"#{nd[:data][field]}\""
      s += "^^#{type}" if type and type !~ /^xsd:string/
      s += "#{lang}" if lang and type == 'xsd:string'
    end

    ret << s + " ."

    return ret
  end

  def self.turtelize(cdk_id, h, params)
    triples = []
    gdatas = []
    params[:layerdataproperties] = Set.new if params[:layerdataproperties].nil?
    base_uri = "#{cdk_id}/"
    h.each do |nd|
      gdatas += self.turtelize_one(nd,triples,base_uri,params,cdk_id)
    end
    return triples, gdatas
  end


  def self.serialize(cdk_id, h, params)
    newh = {}
    h.each do |nd|

      layer_id = nd[:layer_id]

      name = Layer.nameFromId(layer_id)

      nd.delete(:validity)
      # rt,vl = Layer.get_validity(layer_id)
      # if(rt)
      #   nd.delete(:validity)
      #   nd[:update_rate] = vl
      # else
      #   nd[:validity] = vl if nd[:validity].nil?
      #   nd[:validity] = [nd[:validity].begin, nd[:validity].end] if nd[:validity]
      # end
      # nd.delete(:validity) if nd[:validity].nil?

      nd.delete(:tags) if nd[:tags].nil?

      if nd[:modalities]
        nd[:modalities] = nd[:modalities].map { |m| Modality.NameFromId(m) }
      else
        nd.delete(:modalities)
      end

      nd.delete(:id)
      nd.delete(:node_id)
      nd.delete(:parent_id)
      nd.delete(:layer_id)
      nd.delete(:created_at)
      nd.delete(:updated_at)
      nd.delete(:node_data_type)
      nd.delete(:created_at)
      nd.delete(:updated_at)

      if Layer.isWebservice?(layer_id) and !params.has_key?('skip_webservice')
        nd[:data] = WebService.load(layer_id, cdk_id, nd[:data])
      end

      nd[:data] = nest(nd[:data].to_hash)
      newh[name] = nd
    end
    newh
  end

end
