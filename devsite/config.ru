require 'bundler'
require 'rubygems'

Bundler.require

require './dev.citysdk.rb'

use Rack::Static, :urls => ["/css", "/script"], :root => "public"
run CSDK_Docs

