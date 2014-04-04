class CitySDKAPI < Sinatra::Application

  module Routes

    def self.processCommand?(n,params)
      ['nodes','start_end','routes'].include?(params[:cmd])
    end

    def self.processCommand(n, params, req)
      cdk_id = params['cdk_id']
      if params[:cmd] == 'nodes'
        pgn = CitySDK::Node.dataset
          .where(:nodes__id => Sequel.function(:ANY, Sequel.function(:get_members, cdk_id)))
          .nodedata(params)
          .node_layers(params)
          .do_paginate(params)
          .order(Sequel.function('idx', Sequel.function(:get_members, cdk_id),
                                 Sequel.cast(:nodes__id, :bigint)))

        CitySDKAPI.nodes_results(pgn, params, req)
      elsif params[:cmd] == 'start_end'
        pgn = CitySDK::Node.dataset
          .where(:nodes__id => Sequel.function(:ANY, Sequel.function(:get_start_end, cdk_id)))
          .nodedata(params)
          .node_layers(params)

        CitySDKAPI.nodes_results(pgn, params, req)
      elsif params[:cmd] == 'routes'

        sql_where = <<-SQL
          cdk_id = ANY(ARRAY(
            SELECT nodes.cdk_id FROM nodes
            INNER JOIN nodes AS route_nodes ON (route_nodes.members && nodes.members)
            WHERE route_nodes.cdk_id = ?)) AND
            nodes.cdk_id != ?
        SQL

        pgn = CitySDK::Node.dataset
          .where(sql_where.lit(cdk_id, cdk_id))
          .name_search(params)
          .route_members(params)
          .nodedata(params)
          .node_layers(params)
          .do_paginate(params)

        CitySDKAPI.nodes_results(pgn, params, req)
      else
        CitySDKAPI.do_abort(422,"Command #{params[:cmd]} not defined for this node type.")
      end
    end
  end

end
