class CitySDKAPI < Sinatra::Application
  get '/:cdk_id/select/:cmd/' do
    n = Node.where(:cdk_id=>params[:cdk_id]).first
    if n.nil?
      CitySDKAPI.do_abort(422,"Node not found: #{params[:cdk_id]}")
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
      CitySDKAPI.do_abort(422,"Unknown command for #{params[:cdk_id]} ")
    end # case
  end # do
end # class

