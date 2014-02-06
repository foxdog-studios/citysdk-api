# encoding: utf-8

# Add the application directory to the load path.
root = File.realpath(File.dirname(__FILE__))
$LOAD_PATH << root unless $LOAD_PATH.include?(root)

# Run the CitySDK API application.
require 'app'
run CitySDKAPI

