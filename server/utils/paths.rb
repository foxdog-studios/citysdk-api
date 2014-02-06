# encoding: utf-8

class CitySDKAPI < Sinatra::Application
  def path_cdk_nodes(node_type = nil)
    pgn =
      if node_type
        params["node_type"] = node_type
        Node.dataset
          .where(node_type: node_type)
          .geo_bounds(params)
          .name_search(params)
          .modality_search(params)
          .route_members(params)
          .nodedata(params)
          .node_layers(params)
          .do_paginate(params)
      else
        Node.dataset
          .geo_bounds(params)
          .name_search(params)
          .modality_search(params)
          .route_members(params)
          .nodedata(params)
          .node_layers(params)
          .do_paginate(params)
      end
      CitySDKAPI.nodes_results(pgn, params, request)
  end # def

  def path_regions
    pgn = Node.dataset
      .where(nodes__layer_id: 2)
      .geo_bounds(params)
      .name_search(params)
      .nodedata(params)
      .node_layers(params)
      .do_paginate(params)
    CitySDKAPI.nodes_results(pgn, params, request)
  end # def

end # class
