# encoding: utf-8

require 'dalli'
require 'json'
require 'sinatra'
require 'sinatra/sequel'
require_relative 'config/environment'

class CitySDKAPI < Sinatra::Application
  configure do
    set :protection, except: [:json_csrf]
  end # do

  configure :production do
    PhusionPassenger.on_event(:starting_worker_process) do |forked|
      unless forked
        CitySDKAPI.memcache_new
        Sequel::Model.db.disconnect
      end # unless
    end # do
  end # do
end # class

require 'citysdk'
require_relative 'constants'
require_relative 'utils/init'
require_relative 'helpers/init'
require_relative 'routes/init'
require_relative 'hooks/init'

