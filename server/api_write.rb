require 'json'
require 'rgeo'
require 'rgeo-geojson'

class CitySDK_API < Sinatra::Base

  GEOMETRY_TYPE_POINT   = 'point'
  GEOMETRY_TYPE_LINE    = 'line'
  GEOMETRY_TYPE_POLYGON = 'polygon'
  GEOMETRY_TYPES = [
    GEOMETRY_TYPE_POINT,
    GEOMETRY_TYPE_LINE,
    GEOMETRY_TYPE_POLYGON
  ]

  CREATE_TYPE_UPDATE = 'update'
  CREATE_TYPE_ROUTES = 'routes'
  CREATE_TYPE_CREATE = 'create'
  CREATE_TYPES = [
    CREATE_TYPE_UPDATE,
    CREATE_TYPE_ROUTES,
    CREATE_TYPE_CREATE
  ]

  DEFAULT_RADIUS = 250

  post '/util/match' do
    login_required
    json = JSON.parse(request.body.read)
    require 'pp'; pp json
    pp 'HERE'

    unless json.key?('match') && json.fetch('match').key?(params)
      halt 422, { error: 'No match parameters'}.to_json
    end # unless

    match_params = json["match"]["params"]

    # Abort if nodes have duplicate IDs
    ids = []
    json["nodes"].each do |node|
      id = node['id']
      halt 422, { error: 'Node without ID' }.to_json  if id.nil?
      if ids.include?(id)
        halt 422, { error: "Duplicate ID '#{ id }'" }.to_json
      end # if
      ids << id
    end # do

    known = {}
    if json["match"].has_key? 'known'
      known = json["match"]["known"]

      # All cdk_ids specified in the known object MUST exist in CitySDK.
      # We need to check this first. SQL:
      #    SELECT * FROM unnest(known.values) AS cdk_id
      #    WHERE cdk_id NOT IN (
      #      SELECT cdk_id FROM nodes WHERE cdk_id IN known.values
      #    )

      all_known_cdk_ids = Sequel.function(:unnest, Sequel.pg_array(known.values)).as(:cdk_id)
      existing_known_cdk_ids = Node.dataset.select(:cdk_id).where(:cdk_id => known.values)
      not_known_cdk_ids = Sequel::Model.db[all_known_cdk_ids].where(Sequel.negate(:cdk_id => existing_known_cdk_ids)).all

      if not_known_cdk_ids.length > 0
        CitySDK_API.do_abort(422, "'known' object specifies cdk_ids that do not exist in CitySDK: #{not_known_cdk_ids.map{|row| row[:cdk_id]}.join(", ")}")
      end # if
    end # if

    debug = match_params.fetch('debug', false)

    radius = DEFAULT_RADIUS
    if match_params.has_key? 'radius'
      radius = match_params['radius'].to_i
      if not radius > 0
        CitySDK_API.do_abort(422, "Wrong value for parameter 'radius': must be integer and larger than 0.")
      end # if
    end # if
    match_params["radius"] = radius

    srid = 4326
    if match_params.has_key? 'srid'
      srid = match_params['srid'].to_i
      if srid <= 0
        CitySDK_API.do_abort(422, "Invalid 'srid' parameter supplied. (#{match_params['srid']})")
      end
    end
    match_params["srid"] = srid

    layerdata_strings = {}
    if match_params.has_key? "layers" and match_params["layers"].is_a? Hash
      match_params["layers"].each { |layer, kvs|
        kvs.each { |k, v|
          if v.is_a? Array
            v = v.join "|"
          end
          layerdata_strings.merge! ({"#{layer}::#{k}" => v})
        }
      }
    end
    CitySDK_API.do_abort(422, "No 'layers' object supplied") if layerdata_strings.length == 0

    results = {
      :status => 'success',
      :match => {
        :params => match_params.clone,
        :results => {
          :found => [],
          :not_found => [],
          :totals => {
            :found => 0,
            :not_found => 0
          }
        }
      },
      :nodes => []
    }

    if debug
      results[:match][:results][:debug] = []
    end

    found_count = 0

    geometry_type = match_params["geometry_type"]
    CitySDK_API.do_abort(422, "Invalid geometry_type specified: #{geometry_type}. Must be one of #{GEOMETRY_TYPES.join(', ')}") if not GEOMETRY_TYPES.include? geometry_type

    match_params["layerdata_strings"] = layerdata_strings
    json["nodes"].each { |node|
      id = node["id"]

      match_node = nil
      match_data = nil
      debug_data = nil
      found = false

      if known.has_key? id
        cdk_id = known[id]
        found = true

        match_node = {
          "cdk_id" => cdk_id,
          "data" => node["data"]
        }
        match_node["modalities"] = node["modalities"] if node["modalities"]

        match_data = {
          :id => id,
          :cdk_id => cdk_id
        }

        debug_data = {
          :found => true,
          :id => id,
          :cdk_id => cdk_id,
          :name => node["name"],
          :known => true
        }
      else
        # TODO: add option to exclude cdk_ids already found in previous matches
        # Matching should occur on one object for one cdk_id per layer per request.
        match_node, match_data, debug_data, found = case geometry_type
          when GEOMETRY_TYPE_POINT
            PointMatcher.match(node, match_params)
          when GEOMETRY_TYPE_LINE
            LineMatcher.match(node, match_params)
          when GEOMETRY_TYPE_POLYGON
            PolygonMatcher.match(node, match_params)
        end
      end

      # TODO: check if match_node does not match againts the same cdk_id twice
      # Keep list of matched cdk_ids, reject if not uniq
      if found
        results[:nodes] << match_node
        results[:match][:results][:found] << match_data if match_data
        found_count += 1
      else # not found
        # If no match is found, add new node itself to result nodes,
        # create API can use this node in same hash to create new node.
        results[:match][:results][:not_found] << match_data if match_data
        results[:nodes] << node
      end

      if debug and debug_data
        results[:match][:results][:debug] << debug_data
      end

    }

    results[:match][:results][:totals][:found]     = found_count
    results[:match][:results][:totals][:not_found] = json["nodes"].length - found_count

    return results.to_json
  end

  put '/nodes/:layer' do |layer_name|
    login_required

    # Get the layer and check it's owner by the user.
    layer = Layer.where(name: layer_name, owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{ layer_name }' does not exist or you are " \
               "not the owner."
      }.to_json
    end # if

    # Load the request body
    json = JSON.load(request.body)

    # Halt if nodes have not been supplied.
    nodes = json['nodes']
    halt 422, { error: 'No node have been supplied' }.to_json if nodes.nil?

    # Get parameters. Halt if no parameters have been supplied.
    create = json['create']
    if create.nil? || create['params'].nil?
      halt 422, { error: 'No create/params object supplied' }.to_json
    end # if
    params = create.fetch('params')
    create_type = params.fetch('create_type')
    node_type = params.fetch('node_type')

    results = {
      status: 'success',
        create: {
        params: params,
        results: {
          created: [],
          updated: [],
          totals: { created: 0, updated: 0 }
        }
      }
    }

    # Get the SRID to use if it has been supplied.
    raw_srid = params.fetch('srid', 4326)
    srid = raw_srid.to_i
    halt 411, { error: "Invalid SRID: #{ raw_srid }" }.to_json if srid.zero?

    # Get modalities, if they have been supplied, and covert them to IDs.
    modalities = params.fetch('modalities', [])
    unless modalities.kind_of?(Array)
      halt 422, { error: 'modalities parameter must be an array' }.to_json
    end # unless
    modalities.map! { |name| Modality.where(name: name).get(:id) }
    modalities = modalities.empty? ? nil : Sequel.pg_array(modalities)

    new_nodes = []
    updated_nodes = []
    node_data = []
    node_data_cdk_ids = []

    nodes.each do |node|
      cdk_id = node['cdk_id']
      cdk_ids = node['cdk_ids']

      unless cdk_id.nil? || cdk_ids.nil?
        halt 422, { error: 'node with both cdk_id and cdk_ids fields' }.to_json
      end # unless

      members = nil

      unless cdk_ids.nil?
        if !cdk_ids.is_a?(Array) || cdk_ids.empty?
          halt 422, { error: 'invalid cdk_ids, must be array' }.to_json
        end # if
        if cdk_ids.length == 1
          cdk_id = cdk_ids[0]
        else
          # Node to be added is a route
          members = cdk_ids.map do |cdk_id|
            Sequel.function(:cdk_id_to_internal, cdk_id)
          end # do
          members = Sequel.pg_array(members)
        end # else
      end # unless

      id = node['id']

      unless id || cdk_id || cdk_ids
        fail 422, { error: 'node without id, cdk_id or cdk_ids' }.to_json
      end # unless

      geom = nil
      if !node['geometry'].nil? && cdk_id.nil?
        geom = node.fetch('geometry')

        # geom must be present if a new node is created,
        # (e.g. when cdk_id and cdk_ids is empty)
        # and must be empty when either of cdk_id or cdk_ids is provided

        # PostGIS can convert GeoJSON to geometry with ST_GeomFromGeoJSON
        # function: geom = Sequel.function(:ST_Transform,
        # Sequel.function(:ST_SetSRID, Sequel.function(:ST_GeomFromGeoJSON,
        # node["geom"].to_json), srid), 4326) But on server this does not work:
        # ERROR:  You need JSON-C for ST_GeomFromGeoJSON
        # TODO: find out why, and maybe update PostgreSQL/PostGIS.

        if geom['type'] == 'wkb'
          # The geometry is already in WKB format with correct SRID.
          wkb = geom.fetch('wkb')
          wkb = Sequel.lit("'#{ wkb }'").cast(:geometry)
        else
          rgeo_geom = RGeo::GeoJSON.decode(geom)
          wkb = CitySDK_API.wkb_generator.generate(rgeo_geom)
          wkb = Sequel.function(
            :ST_SetSRID,
            Sequel.lit("'#{ wkb }'").cast(:geometry),
            srid
          )
        end # else
        geom = Sequel.function(:ST_Transform, wkb, 4326)
      elsif !members.nil?
        # Compute derived geometry from the geometry of members.
        geom = Sequel.function(:route_geometry, members)
      end

      data = node['data']
      if data.nil?
        halt 422, { error: 'node without data encountered' }.to_json
      end # if
      data = Sequel.hstore(data)

      validity = node['validity']
      if !validity.nil?
        unless validity.is_a?(Array) && validity.length == 2
          halt 422, {
            error: "Object with cdk_id=#{cdk_id} submitted with incorrect " \
                   "validity field, must be array with two datetime values, " \
                   "with value 1 < value 2"
          }
        end # unless
        valid_from = DateTime.parse(validity.fetch(0))
        valid_to = DateTime.parse(validity.fetch(1))
        validity = (valid_from..valid_to).pg_range(:tstzrange)
      end # if

      # Create new node and add data when:
      #   - create_type = create
      #   - cdk_id and cdk_ids is empty
      #   - geom is not empty
      check_1 = \
          create_type == 'create' \
          && cdk_id.nil? \
          && cdk_ids.nil? \
          && !geom.nil?

      # Or when:
      #   - create_type = routes (or create_type = create)
      #   - cdk_id is empty
      #   - cdk_ids is not empty
      check_2 = \
          !cdk_id \
          && cdk_ids \
          && %w{create routes}.includes?(create_type)

      # Otherwise, do not create new node, only add data.

      name = node['name']
      if (check_1 || check_2) && !cdk_id
        cdk_id =
          if id
            cdk_id = CitySDK_API.generate_cdk_id_from_text(layer_name, id)
          elsif name
            cdk_id = CitySDK_API.generate_cdk_id_from_text(layer_name, name)
          elsif cdk_ids
            cdk_id = CitySDK_API.generate_route_cdk_id(cdk_ids)
          else
            halt 422, { error: 'No id, name or cdk_ids for new node' }.to_json
          end # else
      end # if

      if Node.where(cdk_id: cdk_id).count.zero?
        node_type_id =
          if node_type
            case node_type
            when 'route'  then 1
            when 'ptstop' then 2
            when 'ptline' then 3
            end # case
          elsif members
            1
          else
            0
          end # else

        new_nodes << {
          cdk_id: cdk_id,
          name: name,
          members: members,
          layer_id: layer.id,
          node_type: node_type_id,
          modalities: modalities,
          geom: geom
        }
      elsif node_type == 'ptstop'
        # node with cdk_id already exist.
        # cdk_id is available, data is added to existing node.
        # If existing node has node_type 'node' and new node is 'ptstop'
        # convert node to ptstop:
        updated_nodes << cdk_id
      end # elsif

      # See if there is node_data to add/update. Otherwise, skip
      if cdk_id
        node_data << {
          node_id: Sequel.function(:cdk_id_to_internal, cdk_id),
          layer_id: layer.id,
          data: data,
          modalities: modalities,
          node_data_type: 0,
          validity: validity
        }
        node_data_cdk_ids << cdk_id
      end # if
    end # do

    db = Sequel::Model.db
    db.transaction do
      db[:nodes].multi_insert(new_nodes)
      Node.where(cdk_id: updated_nodes).update(node_type: 2)
      NodeDatum.where(
        node_id: Sequel.function(
          :any,
          Sequel.function(
            :cdk_ids_to_internal,
            Sequel.pg_array(node_data_cdk_ids)
          )
        )
      ).where(layer_id: layer.id).delete
      db[:node_data].multi_insert(node_data)
    end # do
  end # do

  put '/:cdk_id/:layer' do |cdk_id, layer_name|
    login_required
    layer = Layer.where(name: layer_name, owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{name}' does not exist or you are not the " \
               "owner."
      }.to_json
    end # if

    node = Node.where(:cdk_id => cdk_id).first
    halt 422, { error: "Node '#{ cdk_id }' not found." } if node.nil?

    json = CitySDK_API.parse_request_json(request)['data']
    data = json['data']
    halt 422, { error: "No 'data' found in post." } if data.nil?

    node_data = NodeDatum.where(layer_id: layer_id, node_id: node.id).first
    modalities = json['modalities']
    modalities = [] if modalities.nil?
    modalities = modalities.map { |name| Modality.get_id_for_name(name) }

    if node_data.nil?
      NodeDataum.insert(
        layer_id: layer_id,
        node_id: node.id,
        data: Sequel.hstore(data),
        node_data_type: 0,
        modalities: Sequel.pg_array(modalities)
      )
    else
      unless modalities.nil?
        node_data.modalities << modalities
        node_data.modalities.flatten!.uniq!
      end # unless
      node_data.data.merge!(data)
      node_data.save
    end

    [200, { :status => 'success' }.to_json]
  end # do

  put '/layers/' do
    login_required
    json = JSON.parse(request.body.read)
    halt 422, 'Layer data missing' if json['data'].nil?
    data = json.fetch('data')
    domain = data.fetch('name').split('.')[0]
    user = current_user
    unless user.domains.include?(domain)
      halt 401, "Not authorized for domain #{ domain }"
    end # unless
    layer = Layer.new(data)
    halt 422, layer.errors.to_json unless layer.valid?
    layer.owner_id = user.id
    layer.save
    [200, { :status => 'success' }.to_json]
  end # do

  put '/layers/:layer/config' do |name|
    login_required
    layer = Layer.where(name: name, owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{name}' does not exist or you are not the " \
               "owner."
      }.to_json
    end # if
    data = CitySDK_API.parse_request_json(request)['data']
    halt 422, {error: 'Data missing'}.to_json if data.nil?
    layer.import_config = 'data'
    layer.save
    [200, { :status => 'success' }.to_json]
  end # do

  put '/layers/:layer/status' do |name|
    login_required
    layer = Layer.where(name: name, owner_id: current_user.id).first
    if layer.nil?
      halt 422, {
        error: "Either the layer '#{name}' does not exist or you are not the " \
               "owner."
      }.to_json
    end # if
    data = CitySDK_API.parse_request_json(request)['data']
    halt 422, {error: 'Data missing'}.to_json if data.nil?
    layer.import_status = 'data'
    layer.save
    [200, { :status => 'success' }.to_json]
  end
end # class

