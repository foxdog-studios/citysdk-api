class CitySDK_API < Sinatra::Base
  get '/' do
    kv8  = CitySDK_API::memcache_get('kv8daemon');
    divv = CitySDK_API::memcache_get('divvdaemon');
    @do_cache = false

    case params[:request_format]
    when 'text/turtle'
      a = ["@base <#{CDK_BASE_URI}#{Config[:ep_code]}/> ."]
      a << "@prefix : <#{CDK_BASE_URI}> ."
      a << "@prefix foaf: <http://xmlns.com/foaf/0.1/> ."
      a << "@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> ."
      a << ""
      a << '_:ep'
      a << ' a :CitysdkEndpoint ;'
      a << " rdfs:description \"#{Config[:ep_description]}\" ;"
      a << " :endpointCode \"#{Config[:ep_code]}\" ;"
      a << " :apiUrl \"#{Config[:ep_api_url]}\" ;"
      a << " :cmsUrl \"#{Config[:ep_cms_url]}\" ;"
      a << " :infoUrl \"#{Config[:ep_info_url]}\" ;"
      a << " foaf:mbox \"#{Config[:ep_maintainer_email]}\" ."
      return a.join("\n")
    when 'application/json'
      return { :status => 'success',
        :url => request.url,
        "name" => "CitySDK Version 1.0",
        "description" => "live testing; preliminary documentation @ http://dev.citysdk.waag.org",
        "health" => {
          "kv8" => kv8 ? "alive, #{kv8}" : "dead",
          "divv" => divv ? "alive, last timestamp: #{divv}" : "dead",
        }
      }.to_json
    end
  end

  ###### Data URL handlers:

  get '/regions/?' do
    path_regions
  end

  get '/layers/reload__' do
    @do_cache = false
    Layer.getLayerHashes
    { :status => 'success' }.to_json
  end

  get '/layers/?' do
      params['count'] = ''
      pgn = Layer.dataset
        .name_search(params)
        .category_search(params)
        .layer_geosearch(params)
        .do_paginate(params)

      Node.serializeStart(params,request)
      res = 0
      pgn.each { |l| l.serialize(params,request); res += 1 }
      Node.serializeEnd(params, request, CitySDK_API::pagination_results(params, pgn.get_pagination_data(params), res))
  end

  get '/nodes/?' do
    path_cdk_nodes
  end

  get '/routes/?' do
    path_cdk_nodes(1)
  end

  get '/ptstops/?' do
    path_cdk_nodes(2)
  end

  get '/ptlines/?' do
    path_cdk_nodes(3)
  end

  get '/layers/:name/' do |name|
    layer = Layer[name: name]
    halt 404, { error: "no layer named '#{ name }'" }.to_json if layer.nil?
    Node.serializeStart(params, request)
    layer.serialize(params, request)
    Node.serializeEnd(params, request)
  end

  get '/:within/nodes/?' do
    path_cdk_nodes
  end

  get '/:within/routes/?' do
    path_cdk_nodes(1)
  end

  get '/:within/ptstops/?' do
    path_cdk_nodes(2)
  end

  get '/:within/ptlines/?' do
    path_cdk_nodes(3)
  end

  get '/:within/regions/?' do
    path_regions
  end


  get '/:cdk_id/select/:cmd/?' do
    n = Node.where(:cdk_id=>params[:cdk_id]).first
    if n.nil?
      CitySDK_API.do_abort(422,"Node not found: #{params[:cdk_id]}")
    end

    code = 0, h = {}
    case n.node_type
      when 0 # nodes
        Nodes.processCommand(n,params,request)
      when 1 # routes
        Routes.processCommand(n,params,request)
      when 2 # ptstops
        if( Nodes.processCommand?(n,params) )
          Nodes.processCommand(n,params,request)
        else
          PublicTransport.processStop(n,params,request)
        end
      when 3 # ptlines
        if( Routes.processCommand?(n,params) )
          Routes.processCommand(n,params,request)
        else
          PublicTransport.processLine(n,params,request)
        end
      else
        CitySDK_API.do_abort(422,"Unknown command for #{params[:cdk_id]} ")
    end
  end

  get '/:node/:layer/?' do
    if 0 == Node.where(:cdk_id=>params[:node]).count
      CitySDK_API.do_abort(422,"Node not found: '#{params[:node]}'")
    end
    if 0 == Layer.where(:name=>params[:layer]).count
      CitySDK_API.do_abort(422,"Layer not found: '#{params[:layer]}'")
    end
    n  = Node.where(:cdk_id=>params[:node]).first
    nd = NodeDatum.where(:layer_id => Layer.idFromText(params[:layer])).where(:node_id => n.id).first

    case params[:request_format]
    when 'application/json'
      { :status => 'success',
        :url => request.url,
        :results => [NodeDatum.serialize(params[:node],[nd.values],params)]
      }.to_json
    when 'text/turtle'
      Node.serializeStart(params,request)
      t,d = NodeDatum.turtelize(params[:node],[nd.values],params)
      [Node.prefixes.join("\n"),Node.layerProps(params).join("\n"),d.join("\n")].join("\n")
    end

  end


  get '/:node/?' do
    results = Node.where(:cdk_id=>params[:node])
      .node_layers(params)
      .nodes(params)
    if 0 == results.length
      CitySDK_API.do_abort(422,"Node not found: '#{params[:node]}'")
    end
    Node.serializeStart(params, request)
    if params[:p]
      Node.processPredicate(results.first,params)
    else
      results.map { |item| Node.serialize(item,params) }
    end
    Node.serializeEnd(params, request)
  end

end
