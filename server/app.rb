# encoding: utf-8

require 'sinatra'
require 'sinatra/sequel'

require_relative 'config/environment'


class CitySDKAPI < Sinatra::Application

  configure :production do
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      return if forked
      CitySDKAPI.memcache_new
      Sequel::Model.db.disconnect
    end # do
  end # do

  configure do
    set :protection, except: [:json_csrf]
  end # do

end # class

require_relative 'utils/init'
require_relative 'models/init'
require_relative 'helpers/init'
require_relative 'routes/init'
require_relative 'hooks/init'

