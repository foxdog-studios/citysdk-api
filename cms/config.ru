require 'bundler'
require 'i18n'
require 'rubygems'

Bundler.require

require './csdk_cms.rb'

use Rack::Static, :urls => ["/css", "/script"], :root => "public"
run CSDK_CMS

