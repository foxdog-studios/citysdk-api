class CitySDKAPI < Sinatra::Application
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
        CitySDKAPI.do_abort(422, "'known' object specifies cdk_ids that do not exist in CitySDK: #{not_known_cdk_ids.map{|row| row[:cdk_id]}.join(", ")}")
      end # if
    end # if

    debug = match_params.fetch('debug', false)

    radius = DEFAULT_RADIUS
    if match_params.has_key? 'radius'
      radius = match_params['radius'].to_i
      if not radius > 0
        CitySDKAPI.do_abort(422, "Wrong value for parameter 'radius': must be integer and larger than 0.")
      end # if
    end # if
    match_params["radius"] = radius

    srid = 4326
    if match_params.has_key? 'srid'
      srid = match_params['srid'].to_i
      if srid <= 0
        CitySDKAPI.do_abort(422, "Invalid 'srid' parameter supplied. (#{match_params['srid']})")
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
    CitySDKAPI.do_abort(422, "No 'layers' object supplied") if layerdata_strings.length == 0

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
    CitySDKAPI.do_abort(422, "Invalid geometry_type specified: #{geometry_type}. Must be one of #{GEOMETRY_TYPES.join(', ')}") if not GEOMETRY_TYPES.include? geometry_type

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
end # class

