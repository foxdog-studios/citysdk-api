# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/get_layer_stats/:layer' do |l|
      l = Layer.where(name: l).first
      @lstatus = l.import_status || '-'
      @ndata   = NodeData.where(:layer_id => l.id).count
      @ndataua = NodeData.select(:updated_at).where(:layer_id => l.id).order(:updated_at).reverse.limit(1).all
      @ndataua = ( @ndataua and @ndataua[0] ) ? @ndataua[0][:updated_at] : '-'
      @nodes   = Node.where(:layer_id => l.id).count
      @delcommand = "delUrl('/layer/" + l.id.to_s + "',null,$('#stats'))"
      erb :stats, :layout => false
    end # do
  end # class
end # module

