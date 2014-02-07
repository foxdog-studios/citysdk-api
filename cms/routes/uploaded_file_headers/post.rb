# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/uploaded_file_headers' do
      require 'pp'
      pp params
      params.each do |k,v|
        params.delete(k) if v =~ /^<no\s+/
      end # do

      redirect "/get_layer_stats/#{params[:layer_name]}"
    end # do
  end # class
end # module

