# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/prefixes' do
      login_required
      if params[:prefix] and params[:name] and params[:uri]
        if params[:prefix][-1] != ':'
          params[:prefix] = params[:prefix] + ':'
        end # if
        pr = LDPrefix.new( {
          :prefix => params[:prefix],
          :name => params[:name],
          :url => params[:uri],
          :owner_id => @oid
        })
        pr.save
      end # if
      @prefixes = LDPrefix.order(:name).all
      erb :prefixz, :layout => false
    end # do
  end # class
end # module

