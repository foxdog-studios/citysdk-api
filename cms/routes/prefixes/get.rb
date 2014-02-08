# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/prefixes' do
      login_required

      # XXX: Does this create a prefix using the query parameters?
      #      If so, this needs to be put on a post!
      if params[:prefix] and params[:name] and params[:uri]
        if params[:prefix][-1] != ':'
          params[:prefix] = params[:prefix] + ':'
        end # if
        pr = LDPrefix.new({
          :prefix => params[:prefix],
          :name => params[:name],
          :url => params[:uri],
          :owner_id => current_user.id
        })
        pr.save
      end # if

      @prefixes = LDPrefix.order(:name).all
      haml :prefixz, :layout => false
    end # do
  end # class
end # module

