# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    get '/layer/new' do
      login_required
      @owner = current_user
      domains = @owner.domains
      if( domains.length > 1 )
        @prefix  = "<select name='prefix'> "
        domains.uniq.each do |p|
          @prefix += "<option>#{p}</option>"
        end
        @prefix += "</select>"
      else
        @prefix = domains[0]
      end
      @layer = Layer.new
      @layer.data_sources = []
      @layer.update_rate = 3600
      @layer.organization = @owner.organization
      @categories = @layer.cat_select
      @webservice = false
      erb :new_layer
    end # do
  end # class
end # module

