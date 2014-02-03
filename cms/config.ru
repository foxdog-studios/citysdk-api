require 'bundler'
require 'i18n'

Bundler.require

require './csdk_cms.rb'

use Rack::Static, root: 'public', urls: %w(/css /script)
run CSDK_CMS

