require 'bundler'
# XXX: Adding the following require stops the application crashing on start up
#      but we're not sure it solves the underlying problem.
require 'i18n'
require 'rubygems'

Bundler.require

require './api.rb'
run CitySDK_API

