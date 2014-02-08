# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    delete '/prefix/:pr' do |p|
      login_required
      LDPrefix.where(owner_id: current_user.id, prefix: p).delete
      @prefixes = LDPrefix.order(:name).all
      haml :prefixz, :layout => false
    end # do
  end # class
end # module

