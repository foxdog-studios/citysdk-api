class CitySDKAPI < Sinatra::Application

  module Nodes

    def self.processCommand?(n,params)
      ['routes','regions', 'routes_start', 'routes_end'].include?(params[:cmd])
    end

    def self.processCommand(n, params, req)
      cdk_id = params['cdk_id']

      if params[:cmd] == 'routes'

        pgn = CitySDK::Node.dataset
          .where("members @> ARRAY[cdk_id_to_internal('#{cdk_id}')]")
          .name_search(params)
          .route_members(params)
          .nodedata(params)
          .node_layers(params)
          .do_paginate(params)

        CitySDKAPI.nodes_results(pgn, params, req)

      elsif params[:cmd] == 'routes_start' or params[:cmd] == 'routes_end'
        # Select all routes that start or end in cdk_id,
        # i.e. cdk_id = members[0] or cdk_id = members[-1]
        #
        # Example:
        #   SELECT * FROM nodes
        #   WHERE cdk_id_to_internal('n712651044') = members[array_lower(members, 1)]

        array_function = :array_lower
        if params[:cmd] == 'routes_end'
          array_function = :array_upper
        end

        pgn = CitySDK::Node.dataset
          .where(Sequel.function(:cdk_id_to_internal, cdk_id) =>  Sequel.pg_array(:members)[Sequel.function(array_function, :members, 1)])
          .name_search(params)
          .route_members(params)
          .nodedata(params)
          .node_layers(params)
          .do_paginate(params)

        CitySDKAPI.nodes_results(pgn, params, req)

      elsif params[:cmd] == 'regions'

        # TODO: hard-coded layer_id of admr = 2!
        layers = [0,1,2]
        if params.has_key? 'layer'
          layers = CitySDK::Layer.idFromText(params['layer'].split(','))
        end

        # TODO: also filter on node_data, name etc!
        # TODO: hard-coded layer_id of admr = 2!
        CitySDK::Node.serializeStart(params,req)
        res = CitySDK::Node.dataset
          .join_table(:inner, :nodes, Sequel.function(:ST_Intersects, :nodes__geom, :containing_node__geom), {:table_alias=>:containing_node})
          .where(:containing_node__cdk_id=>cdk_id)
          .where(:nodes__layer_id=>2)
          .select_all(:nodes)
          .eager_graph(:node_data).where(:node_data__layer_id => layers)
          .order(Sequel.lit("(data -> 'admn_level')::int")).reverse
          .all.map { |a|
            a.values.merge(:node_data=>a.node_data.map { |al|
              al.values
            } )
          }
          .each { |item| CitySDK::Node.serialize(item,params) }

          # .map { |item| Node.serialize(item,params) }
          CitySDK::Node.serializeEnd(params, req)

        #
        #
        # CitySDKAPI.json_simple_results(res, req)
      else
        CitySDKAPI.do_abort(422,"Command #{params[:cmd]} not defined for this node type.")
      end
    end
  end

end
