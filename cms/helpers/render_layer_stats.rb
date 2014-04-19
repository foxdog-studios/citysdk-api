# -*- encoding: utf-8 -*-

module CitySDK
  class CMSApplication < Sinatra::Application
    helpers do
      def render_layer_stats(layer)
        num_nodes = Node.where(layer_id: layer.id).count
        data_set_size = NodeDatum.where(layer_id: layer.id).count
        last_updated = NodeDatum.max(:updated_at)

        status =
          if layer.import && !layer.import.status.empty?
            layer.import.status
          else
            'Not imported yet'
          end # else

        haml :stats, layout: false, locals: {
          num_nodes: num_nodes,
          data_set_size: data_set_size,
          last_updated: last_updated,
          status: status
        }
      end # def
    end # do
  end # class
end # module

