# encoding: utf-8

module CitySDK
  class CMSApplication < Sinatra::Application
    post '/uploaded_file_headers' do
      if params['add']
        parameters = JSON.parse(Base64.decode64(params['parameters']),
                                {:symbolize_names => true})
        params.delete('parameters')
        parameters = parameters.merge(params)

        parameters.each do |k,v|
          parameters.delete(k) if v =~ /^<no\s+/
        end # do
        parameters[:host] = @api_server
        parameters[:email] = session[:e]
        parameters[:passw] = session[:p]

        import_log_path = $config['cms_import_log_path']
        parameters_json = parameters.to_json
        import_file_command = "ruby utils/import_file.rb '#{parameters_json}'"
        import_log_command = "#{import_file_command} >> #{import_log_path} &"
        system import_log_command

        parameters.delete(:email)
        parameters.delete(:passw)
        parameters.delete(:file_path)
        parameters.delete(:originalfile)

        api = CitySDK::API.new(@api_server)

        api.authenticate(session[:e], session[:p]) do
          d = { :data => Base64.encode64(parameters.to_json) }
          api.put("/layer/#{parameters[:layername]}/config",d)
        end # do

        redirect "/get_layer_stats/#{parameters[:layername]}"
      else
        a = matchCSV(params)
        a = JSON.pretty_generate(a)
        return [200, {} ,"<hr/><pre>#{ a }</pre>"]
      end # else
    end # do
  end # class
end # module

